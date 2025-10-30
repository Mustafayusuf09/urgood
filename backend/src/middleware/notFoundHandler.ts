import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

// 404 Not Found handler
export function notFoundHandler(req: Request, res: Response, next: NextFunction): void {
  // Log the 404 for monitoring
  logger.warn('Route not found', {
    method: req.method,
    path: req.path,
    query: req.query,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    userId: req.user?.id
  });
  
  // Check if it's an API request
  const isAPIRequest = req.path.startsWith('/api/');
  
  if (isAPIRequest) {
    // Return JSON response for API requests
    res.status(404).json({
      success: false,
      message: 'API endpoint not found',
      path: req.path,
      method: req.method,
      timestamp: new Date().toISOString(),
      availableEndpoints: [
        'GET /api/v1/health',
        'POST /api/v1/auth/login',
        'POST /api/v1/auth/register',
        'GET /api/v1/users/profile',
        'POST /api/v1/chat/messages',
        'GET /api/docs'
      ]
    });
  } else {
    // Return HTML response for web requests
    res.status(404).send(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>404 - Page Not Found</title>
        <style>
          body { 
            font-family: Arial, sans-serif; 
            text-align: center; 
            padding: 50px; 
            background-color: #f5f5f5; 
          }
          .container { 
            max-width: 600px; 
            margin: 0 auto; 
            background: white; 
            padding: 40px; 
            border-radius: 8px; 
            box-shadow: 0 2px 10px rgba(0,0,0,0.1); 
          }
          h1 { color: #333; }
          p { color: #666; }
          .links { margin-top: 30px; }
          .links a { 
            display: inline-block; 
            margin: 10px; 
            padding: 10px 20px; 
            background: #007bff; 
            color: white; 
            text-decoration: none; 
            border-radius: 4px; 
          }
          .links a:hover { background: #0056b3; }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>404 - Page Not Found</h1>
          <p>The page you're looking for doesn't exist.</p>
          <p>Path: <code>${req.path}</code></p>
          <div class="links">
            <a href="/api/docs">API Documentation</a>
            <a href="/health">Health Check</a>
          </div>
        </div>
      </body>
      </html>
    `);
  }
}

export default notFoundHandler;
