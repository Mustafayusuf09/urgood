# Repository Guidelines

## Project Structure & Module Organization
- `backend/` — TypeScript/Express API; source in `src/`, routes in `src/routes/`, utilities in `src/utils/`, builds in `dist/`, tests in `tests/`.
- `firebase-functions/` — TypeScript Cloud Functions (entry `src/index.ts`) for async messaging, schedulers, and Firebase-native integrations.
- `urgood/` — SwiftUI app structured by MVVM (`App/`, `Core/`, `Design/`, `Features/`) plus admin dashboard and marketing assets; XCTest suites in `urgood/Tests/`.
- Root playbooks (`*_SETUP.md`, launch checklists) document compliance and release flows—review them before shipping or altering environments.

## Build, Test, and Development Commands
- Backend: `npm install`, `npm run dev`, `npm run build`, `npm start`.
- Quality gates: `npm run test`, `npm run test:coverage` (≥90% line coverage), `npm run lint`, `npx prisma migrate dev`.
- Firebase: `npm run build`, `npm run serve`, `npm run deploy`.
- iOS: open `urgood/urgood.xcodeproj` or run `xcodebuild -scheme urgood -destination 'platform=iOS Simulator,name=iPhone 15' test`.

## Coding Style & Naming Conventions
- TypeScript uses 2-space indentation, camelCase for functions and variables, PascalCase for classes, snake_case for environment keys; rely on ESLint plus `npm run lint:fix`.
- Swift screens end in `View`, view models in `ViewModel`, shared UI in `Design/Components`; prefer async/await and avoid force unwraps.
- Secrets stay out of Git—clone `backend/env.example` (and Firebase CLI configs) into local `.env` files.

## Testing Guidelines
- Backend Jest specs live in `backend/tests/*.test.ts`; mirror feature names (`chat.test.ts`) for clarity, including integration suites.
- Use `backend/tests/setup.ts` to mock OpenAI, Stripe, Twilio, and Firebase so runs remain deterministic.
- Firebase Functions follow the same Jest flow; place mirrors under `src/__tests__/`.
- iOS XCTest targets belong in `urgood/Tests/`; snapshot or async-test new view models and services.

## Commit & Pull Request Guidelines
- Follow Conventional Commits (`feat:`, `fix:`, `chore:`) with scopes tied to modules such as `auth`, `billing`, or `voice-chat`.
- Limit PRs to focused changes (<500 LOC), link tickets or issues, note affected environments, and attach screenshots or logs for UI or infra updates.
- Confirm lint, tests, and Prisma migration output in the PR body; call out required environment updates explicitly.

## Environment & Security Notes
- Start local dependencies with `docker-compose up -d` from `backend/`; seed disposable databases via `npm run db:seed`.
- Register new routes with the Swagger loader in `src/routes` so `/api/docs` stays accurate.
- Rotate API keys when sharing builds and audit `backend/logs/` after authentication changes.
