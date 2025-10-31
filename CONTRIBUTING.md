# Contributing to UrGood

Thank you for your interest in contributing to UrGood! This document provides guidelines and instructions for contributing to the project.

## 🚀 Getting Started

### Development Setup

1. **Fork the repository**
   ```bash
   git clone https://github.com/yourusername/urgood.git
   cd urgood
   ```

2. **Set up iOS Development**
   - Open `urgood/urgood.xcodeproj` in Xcode 15.0+
   - Select your development team in project settings
   - Build and run on simulator or device

3. **Set up Backend Development**
   ```bash
   cd backend
   npm install
   cp env.example .env
   # Edit .env with your configuration
   npm run dev
   ```

4. **Set up Firebase Functions**
   ```bash
   cd firebase-functions
   npm install
   ```

## 📝 Code Style

### Swift (iOS)
- Follow Swift API Design Guidelines
- Use SwiftUI best practices
- Follow MVVM architecture pattern
- Use meaningful variable and function names
- Add comments for complex logic

### TypeScript (Backend)
- Follow TypeScript strict mode
- Use ESLint and Prettier formatting
- Follow RESTful API conventions
- Use async/await for async operations
- Add JSDoc comments for public functions

## 🧪 Testing

### Running Tests

**iOS Tests:**
```bash
xcodebuild -scheme urgood -destination 'platform=iOS Simulator,name=iPhone 15' test
```

**Backend Tests:**
```bash
cd backend
npm test
```

### Writing Tests
- Write tests for new features
- Maintain >80% code coverage
- Test both success and error cases
- Include edge cases

## 🔀 Pull Request Process

1. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```

2. **Make your changes**
   - Write clean, readable code
   - Add tests for new functionality
   - Update documentation if needed

3. **Commit your changes**
   ```bash
   git commit -m "Add amazing feature"
   ```
   Use conventional commit messages:
   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation
   - `style:` for formatting
   - `refactor:` for code refactoring
   - `test:` for tests
   - `chore:` for maintenance

4. **Push to your fork**
   ```bash
   git push origin feature/amazing-feature
   ```

5. **Open a Pull Request**
   - Fill out the PR template
   - Describe your changes clearly
   - Link any related issues
   - Request review from maintainers

## 📋 Pull Request Checklist

Before submitting a PR, ensure:

- [ ] Code follows style guidelines
- [ ] Tests pass locally
- [ ] New tests added for new features
- [ ] Documentation updated if needed
- [ ] No breaking changes (or documented if intentional)
- [ ] Code is properly commented
- [ ] No sensitive data committed

## 🐛 Reporting Issues

When reporting issues, please include:

- **Description**: Clear description of the issue
- **Steps to Reproduce**: Detailed steps to reproduce
- **Expected Behavior**: What should happen
- **Actual Behavior**: What actually happens
- **Environment**: iOS version, device, etc.
- **Screenshots**: If applicable

## 💡 Feature Requests

For feature requests:

- Use the "Feature Request" issue template
- Clearly describe the feature
- Explain the use case
- Consider implementation approach

## 🔒 Security

- **Never commit API keys or secrets**
- Report security vulnerabilities privately
- Use environment variables for sensitive data
- Follow security best practices

## 📚 Resources

- [Swift Style Guide](https://swift.org/documentation/api-design-guidelines/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Firebase Documentation](https://firebase.google.com/docs)

## 🤝 Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Provide constructive feedback
- Focus on what's best for the project

## 📞 Getting Help

- **Documentation**: Check the README and docs folder
- **Issues**: Search existing issues first
- **Discussions**: Use GitHub Discussions
- **Email**: hello@urgood.app

---

Thank you for contributing to UrGood! 🎉

