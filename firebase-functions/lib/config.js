"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.corsConfig = exports.securityHeaders = void 0;
exports.getConfig = getConfig;
exports.validateConfig = validateConfig;
exports.getEnvironmentSettings = getEnvironmentSettings;
const functions = __importStar(require("firebase-functions"));
/**
 * Get secure configuration with validation
 */
function getConfig() {
    var _a, _b;
    // Get OpenAI API key
    const openaiKey = ((_a = functions.config().openai) === null || _a === void 0 ? void 0 : _a.key) || process.env.OPENAI_API_KEY;
    if (!openaiKey || openaiKey === 'your-openai-api-key-here') {
        throw new Error('OPENAI_API_KEY not configured. Set with: firebase functions:config:set openai.key="your-key"');
    }
    // Get ElevenLabs API key
    const elevenLabsKey = ((_b = functions.config().elevenlabs) === null || _b === void 0 ? void 0 : _b.key) || process.env.ELEVENLABS_API_KEY;
    if (!elevenLabsKey || elevenLabsKey === 'your-elevenlabs-api-key-here') {
        throw new Error('ELEVENLABS_API_KEY not configured. Set with: firebase functions:config:set elevenlabs.key="your-key"');
    }
    // Environment detection
    const nodeEnv = process.env.NODE_ENV || 'development';
    const region = process.env.FUNCTION_REGION || 'us-central1';
    // Security settings
    const maxRateLimit = parseInt(process.env.MAX_RATE_LIMIT || '100', 10);
    const sessionTimeoutMinutes = parseInt(process.env.SESSION_TIMEOUT_MINUTES || '60', 10);
    return {
        openai: {
            key: openaiKey,
        },
        elevenlabs: {
            key: elevenLabsKey,
        },
        environment: {
            nodeEnv,
            region,
        },
        security: {
            maxRateLimit,
            sessionTimeoutMinutes,
        },
    };
}
/**
 * Validate configuration on startup
 */
function validateConfig() {
    try {
        const config = getConfig();
        console.log('🔧 Firebase Functions Configuration:');
        console.log(`  Environment: ${config.environment.nodeEnv}`);
        console.log(`  Region: ${config.environment.region}`);
        console.log(`  OpenAI Key: ${config.openai.key.substring(0, 10)}...`);
        console.log(`  ElevenLabs Key: ${config.elevenlabs.key.substring(0, 10)}...`);
        console.log(`  Max Rate Limit: ${config.security.maxRateLimit}`);
        console.log(`  Session Timeout: ${config.security.sessionTimeoutMinutes} minutes`);
        console.log('✅ Configuration validation passed');
    }
    catch (error) {
        console.error('❌ Configuration validation failed:', error);
        throw error;
    }
}
/**
 * Get environment-specific settings
 */
function getEnvironmentSettings() {
    const config = getConfig();
    const isProduction = config.environment.nodeEnv === 'production';
    return {
        isProduction,
        isDevelopment: !isProduction,
        rateLimits: {
            voiceChat: isProduction ? 5 : 20, // Sessions per hour
            tts: isProduction ? 30 : 100, // Requests per minute
            general: isProduction ? 100 : 500, // General API calls per hour
        },
        subscriptionRequired: {
            voiceChat: isProduction, // Require premium in production
            advancedFeatures: isProduction, // Require premium for advanced features
        },
        logging: {
            level: isProduction ? 'info' : 'debug',
            includeUserData: !isProduction, // Only log user data in development
        },
    };
}
/**
 * Security headers for HTTP functions
 */
exports.securityHeaders = {
    'Content-Type': 'application/json',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '1; mode=block',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
};
/**
 * CORS configuration
 */
exports.corsConfig = {
    origin: [
        'https://urgood-dc7f0.web.app',
        'https://urgood-dc7f0.firebaseapp.com',
        'https://urgood.app',
        ...(process.env.NODE_ENV === 'development' ? ['http://localhost:3000', 'http://127.0.0.1:3000'] : []),
    ],
    credentials: true,
    methods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
};
//# sourceMappingURL=config.js.map