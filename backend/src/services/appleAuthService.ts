import jwt from 'jsonwebtoken';
import { JWK } from 'node-jose';
import { logger } from '../utils/logger';

interface ApplePublicKey {
  kty: string;
  kid: string;
  use: string;
  alg: string;
  n: string;
  e: string;
}

interface AppleKeysResponse {
  keys: ApplePublicKey[];
}

interface AppleIDTokenPayload {
  iss: string;
  aud: string;
  exp: number;
  iat: number;
  sub: string;
  at_hash?: string;
  email?: string;
  email_verified?: string;
  is_private_email?: string;
  auth_time?: number;
  nonce_supported?: boolean;
  real_user_status?: number;
}

class AppleAuthService {
  private static instance: AppleAuthService;
  private appleKeys: Map<string, string> = new Map();
  private lastKeysFetch: number = 0;
  private readonly KEYS_CACHE_DURATION = 24 * 60 * 60 * 1000; // 24 hours
  private readonly APPLE_KEYS_URL = 'https://appleid.apple.com/auth/keys';
  private readonly APPLE_ISSUER = 'https://appleid.apple.com';

  static getInstance(): AppleAuthService {
    if (!AppleAuthService.instance) {
      AppleAuthService.instance = new AppleAuthService();
    }
    return AppleAuthService.instance;
  }

  async verifyAppleToken(identityToken: string, clientId?: string): Promise<AppleIDTokenPayload | null> {
    try {
      // Decode token header to get key ID
      const decodedHeader = jwt.decode(identityToken, { complete: true });
      if (!decodedHeader || typeof decodedHeader === 'string') {
        logger.error('Invalid Apple ID token format');
        return null;
      }

      const { kid } = decodedHeader.header;
      if (!kid) {
        logger.error('Missing key ID in Apple ID token header');
        return null;
      }

      // Get Apple's public key
      const publicKey = await this.getApplePublicKey(kid);
      if (!publicKey) {
        logger.error('Could not retrieve Apple public key for kid:', kid);
        return null;
      }

      // Verify and decode the token
      const payload = jwt.verify(identityToken, publicKey, {
        algorithms: ['RS256'],
        issuer: this.APPLE_ISSUER,
        audience: clientId || 'com.urgood.urgood' // Your app's bundle ID
      }) as AppleIDTokenPayload;

      // Additional validation
      if (!payload.sub) {
        logger.error('Missing subject in Apple ID token');
        return null;
      }

      // Check if token is not expired (JWT library handles this, but double-check)
      const now = Math.floor(Date.now() / 1000);
      if (payload.exp < now) {
        logger.error('Apple ID token has expired');
        return null;
      }

      logger.info('Apple ID token verified successfully', {
        sub: payload.sub,
        email: payload.email,
        emailVerified: payload.email_verified
      });

      return payload;
    } catch (error) {
      logger.error('Apple ID token verification failed:', error);
      return null;
    }
  }

  private async getApplePublicKey(kid: string): Promise<string | null> {
    try {
      // Check if we have cached keys and they're still valid
      const now = Date.now();
      if (this.appleKeys.has(kid) && (now - this.lastKeysFetch) < this.KEYS_CACHE_DURATION) {
        return this.appleKeys.get(kid) || null;
      }

      // Fetch fresh keys from Apple
      await this.fetchApplePublicKeys();
      return this.appleKeys.get(kid) || null;
    } catch (error) {
      logger.error('Error getting Apple public key:', error);
      return null;
    }
  }

  private async fetchApplePublicKeys(): Promise<void> {
    try {
      logger.info('Fetching Apple public keys...');
      
      const response = await fetch(this.APPLE_KEYS_URL);
      if (!response.ok) {
        throw new Error(`Failed to fetch Apple keys: ${response.status}`);
      }

      const keysData: AppleKeysResponse = await response.json();
      
      // Clear existing keys
      this.appleKeys.clear();

      // Convert JWK to PEM format and cache
      for (const key of keysData.keys) {
        if (key.kty === 'RSA' && key.use === 'sig') {
          try {
            const jwkKey = await JWK.asKey({
              kty: key.kty,
              kid: key.kid,
              use: key.use,
              alg: key.alg,
              n: key.n,
              e: key.e
            });

            const pemKey = jwkKey.toPEM();
            this.appleKeys.set(key.kid, pemKey);
            
            logger.debug('Cached Apple public key:', { kid: key.kid });
          } catch (keyError) {
            logger.error('Error processing Apple public key:', { kid: key.kid, error: keyError });
          }
        }
      }

      this.lastKeysFetch = Date.now();
      logger.info(`Successfully cached ${this.appleKeys.size} Apple public keys`);
    } catch (error) {
      logger.error('Failed to fetch Apple public keys:', error);
      throw error;
    }
  }

  // Validate authorization code (for server-to-server verification)
  async validateAuthorizationCode(authorizationCode: string, clientId: string, clientSecret: string): Promise<any> {
    try {
      const tokenEndpoint = 'https://appleid.apple.com/auth/token';
      
      const params = new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        code: authorizationCode,
        grant_type: 'authorization_code'
      });

      const response = await fetch(tokenEndpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: params
      });

      if (!response.ok) {
        const errorText = await response.text();
        logger.error('Apple authorization code validation failed:', {
          status: response.status,
          error: errorText
        });
        return null;
      }

      const tokenData = await response.json();
      logger.info('Apple authorization code validated successfully');
      
      return tokenData;
    } catch (error) {
      logger.error('Error validating Apple authorization code:', error);
      return null;
    }
  }

  // Generate client secret for server-to-server communication
  generateClientSecret(teamId: string, clientId: string, keyId: string, privateKey: string): string {
    const now = Math.floor(Date.now() / 1000);
    
    const payload = {
      iss: teamId,
      iat: now,
      exp: now + (6 * 30 * 24 * 60 * 60), // 6 months
      aud: 'https://appleid.apple.com',
      sub: clientId
    };

    return jwt.sign(payload, privateKey, {
      algorithm: 'ES256',
      header: {
        kid: keyId,
        alg: 'ES256'
      }
    });
  }
}

export const appleAuthService = AppleAuthService.getInstance();
export { AppleIDTokenPayload };
