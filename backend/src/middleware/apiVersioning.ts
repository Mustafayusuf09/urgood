import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';
import { captureMessage } from '../utils/sentry';

// API Version configuration
export const API_VERSIONS = {
  V1: 'v1',
  V2: 'v2',
  CURRENT: 'v1',
  SUPPORTED: ['v1'] as string[],
  DEPRECATED: [] as string[],
  SUNSET: {} as Record<string, Date>
};

// Version detection strategies
export enum VersionStrategy {
  HEADER = 'header',
  URL_PATH = 'url_path',
  QUERY_PARAM = 'query_param',
  ACCEPT_HEADER = 'accept_header'
}

// API versioning middleware
export function apiVersioning(options: {
  strategy?: VersionStrategy;
  defaultVersion?: string;
  headerName?: string;
  queryParam?: string;
  strict?: boolean;
} = {}) {
  const {
    strategy = VersionStrategy.URL_PATH,
    defaultVersion = API_VERSIONS.CURRENT,
    headerName = 'API-Version',
    queryParam = 'version',
    strict = false
  } = options;

  return (req: Request, res: Response, next: NextFunction): void => {
    let version = defaultVersion;
    let detectionMethod = 'default';

    try {
      // Detect version based on strategy
      switch (strategy) {
        case VersionStrategy.HEADER:
          const headerVersion = req.headers[headerName.toLowerCase()] as string;
          if (headerVersion) {
            version = headerVersion;
            detectionMethod = 'header';
          }
          break;

        case VersionStrategy.URL_PATH:
          const pathMatch = req.path.match(/^\/api\/v(\d+)/);
          if (pathMatch) {
            version = `v${pathMatch[1]}`;
            detectionMethod = 'url_path';
          }
          break;

        case VersionStrategy.QUERY_PARAM:
          const queryVersion = req.query[queryParam] as string;
          if (queryVersion) {
            version = queryVersion;
            detectionMethod = 'query_param';
          }
          break;

        case VersionStrategy.ACCEPT_HEADER:
          const acceptHeader = req.headers.accept;
          if (acceptHeader) {
            const versionMatch = acceptHeader.match(/application\/vnd\.urgood\.v(\d+)\+json/);
            if (versionMatch) {
              version = `v${versionMatch[1]}`;
              detectionMethod = 'accept_header';
            }
          }
          break;
      }

      // Validate version
      if (!API_VERSIONS.SUPPORTED.includes(version)) {
        if (strict) {
          res.status(400).json({
            success: false,
            error: 'UNSUPPORTED_API_VERSION',
            message: `API version '${version}' is not supported`,
            supportedVersions: API_VERSIONS.SUPPORTED,
            currentVersion: API_VERSIONS.CURRENT
          });
          return;
        } else {
          // Fall back to default version
          logger.warn('Unsupported API version requested', {
            requestedVersion: version,
            defaultVersion,
            path: req.path,
            method: req.method,
            userAgent: req.get('User-Agent')
          });
          version = defaultVersion;
          detectionMethod = 'fallback';
        }
      }

      // Check for deprecated versions
      if (API_VERSIONS.DEPRECATED.includes(version)) {
        const sunsetDate = API_VERSIONS.SUNSET[version];
        const warningMessage = sunsetDate 
          ? `API version ${version} is deprecated and will be sunset on ${sunsetDate.toISOString()}`
          : `API version ${version} is deprecated`;

        // Add deprecation headers
        res.set('Deprecation', 'true');
        res.set('Sunset', sunsetDate?.toUTCString() || '');
        res.set('Link', `</api/${API_VERSIONS.CURRENT}>; rel="successor-version"`);
        
        logger.warn('Deprecated API version used', {
          version,
          path: req.path,
          method: req.method,
          userAgent: req.get('User-Agent'),
          sunsetDate: sunsetDate?.toISOString()
        });

        // Track deprecated API usage
        captureMessage(`Deprecated API version ${version} used`, 'warning', {
          tags: {
            api_version: version,
            endpoint: req.path,
            method: req.method
          },
          extra: {
            userAgent: req.get('User-Agent'),
            sunsetDate: sunsetDate?.toISOString()
          }
        });
      }

      // Attach version info to request
      req.apiVersion = version;
      req.versionDetectionMethod = detectionMethod;

      // Add version headers to response
      res.set('API-Version', version);
      res.set('API-Supported-Versions', API_VERSIONS.SUPPORTED.join(', '));

      // Log version usage for analytics
      logger.debug('API version detected', {
        version,
        detectionMethod,
        path: req.path,
        method: req.method
      });

      next();
    } catch (error) {
      logger.error('API versioning middleware error', {
        error: error instanceof Error ? error.message : 'Unknown error',
        path: req.path,
        method: req.method
      });
      
      // Fall back to default version on error
      req.apiVersion = defaultVersion;
      req.versionDetectionMethod = 'error_fallback';
      next();
    }
  };
}

// Version-specific route handler
export function versionedRoute(handlers: Record<string, any>) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const version = req.apiVersion || API_VERSIONS.CURRENT;
    const handler = handlers[version] || handlers[API_VERSIONS.CURRENT];
    
    if (!handler) {
      res.status(501).json({
        success: false,
        error: 'VERSION_NOT_IMPLEMENTED',
        message: `Version ${version} is not implemented for this endpoint`,
        supportedVersions: Object.keys(handlers)
      });
      return;
    }

    // Execute version-specific handler
    handler(req, res, next);
  };
}

// Response transformation middleware for backward compatibility
export function responseTransformer(req: Request, res: Response, next: NextFunction) {
  const originalJson = res.json;
  const version = req.apiVersion || API_VERSIONS.CURRENT;

  res.json = function(data: any) {
    // Transform response based on API version
    const transformedData = transformResponseForVersion(data, version, req.path);
    return originalJson.call(this, transformedData);
  };

  next();
}

// Transform response data based on API version
function transformResponseForVersion(data: any, version: string, path: string): any {
  if (!data || typeof data !== 'object') {
    return data;
  }

  switch (version) {
    case 'v1':
      return transformToV1(data, path);
    case 'v2':
      return transformToV2(data, path);
    default:
      return data;
  }
}

// V1 response transformations (current format)
function transformToV1(data: any, path: string): any {
  // V1 is the current format, no transformation needed
  return data;
}

// V2 response transformations (future format)
function transformToV2(data: any, path: string): any {
  // Example V2 transformations
  if (data.success !== undefined) {
    // V2 uses 'status' instead of 'success'
    return {
      status: data.success ? 'ok' : 'error',
      ...data,
      success: undefined
    };
  }
  
  return data;
}

// Middleware to handle version-specific request validation
export function versionedValidation(validators: Record<string, any>) {
  return (req: Request, res: Response, next: NextFunction) => {
    const version = req.apiVersion || API_VERSIONS.CURRENT;
    const validator = validators[version];
    
    if (validator) {
      return validator(req, res, next);
    }
    
    next();
  };
}

// API version management utilities
export class APIVersionManager {
  static deprecateVersion(version: string, sunsetDate?: Date) {
    if (!API_VERSIONS.DEPRECATED.includes(version)) {
      API_VERSIONS.DEPRECATED.push(version);
    }
    
    if (sunsetDate) {
      API_VERSIONS.SUNSET[version] = sunsetDate;
    }
    
    logger.info(`API version ${version} deprecated`, {
      version,
      sunsetDate: sunsetDate?.toISOString()
    });
  }

  static removeVersion(version: string) {
    const supportedIndex = API_VERSIONS.SUPPORTED.indexOf(version);
    if (supportedIndex > -1) {
      API_VERSIONS.SUPPORTED.splice(supportedIndex, 1);
    }
    
    const deprecatedIndex = API_VERSIONS.DEPRECATED.indexOf(version);
    if (deprecatedIndex > -1) {
      API_VERSIONS.DEPRECATED.splice(deprecatedIndex, 1);
    }
    
    delete API_VERSIONS.SUNSET[version];
    
    logger.info(`API version ${version} removed`, { version });
  }

  static addVersion(version: string, makeCurrent: boolean = false) {
    if (!API_VERSIONS.SUPPORTED.includes(version)) {
      API_VERSIONS.SUPPORTED.push(version);
    }
    
    if (makeCurrent) {
      (API_VERSIONS as any).CURRENT = version;
    }
    
    logger.info(`API version ${version} added`, { version, makeCurrent });
  }

  static getVersionInfo() {
    return {
      current: API_VERSIONS.CURRENT,
      supported: API_VERSIONS.SUPPORTED,
      deprecated: API_VERSIONS.DEPRECATED,
      sunset: API_VERSIONS.SUNSET
    };
  }
}

// Mental health app specific version transformations
export function mentalHealthResponseTransformer(req: Request, res: Response, next: NextFunction) {
  const originalJson = res.json;
  const version = req.apiVersion || API_VERSIONS.CURRENT;

  res.json = function(data: any) {
    const transformedData = transformMentalHealthResponse(data, version, req.path);
    return originalJson.call(this, transformedData);
  };

  next();
}

function transformMentalHealthResponse(data: any, version: string, path: string): any {
  if (!data || typeof data !== 'object') {
    return data;
  }

  // Mental health app specific transformations
  if (path.includes('/mood') && version === 'v1') {
    // V1 mood format compatibility
    if (data.data?.moodEntry) {
      data.data.moodEntry = {
        ...data.data.moodEntry,
        // Ensure V1 compatibility fields
        moodLevel: data.data.moodEntry.mood,
        timestamp: data.data.moodEntry.createdAt
      };
    }
  }

  if (path.includes('/chat') && version === 'v1') {
    // V1 chat format compatibility
    if (data.data?.messages) {
      data.data.messages = data.data.messages.map((msg: any) => ({
        ...msg,
        // V1 compatibility fields
        messageId: msg.id,
        timestamp: msg.createdAt,
        content: msg.message
      }));
    }
  }

  if (path.includes('/voice') && version === 'v1') {
    // V1 voice session format
    if (data.data?.session) {
      data.data.session = {
        ...data.data.session,
        sessionId: data.data.session.id,
        isActive: data.data.session.status === 'active'
      };
    }
  }

  return data;
}

// Extend Express Request interface
declare global {
  namespace Express {
    interface Request {
      apiVersion?: string;
      versionDetectionMethod?: string;
    }
  }
}

export default {
  apiVersioning,
  versionedRoute,
  responseTransformer,
  versionedValidation,
  mentalHealthResponseTransformer,
  APIVersionManager,
  API_VERSIONS,
  VersionStrategy
};
