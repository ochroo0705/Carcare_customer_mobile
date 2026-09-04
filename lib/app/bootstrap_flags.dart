/// Test-only escape hatch. When `true`, the launch splash ([SplashGate]) and the
/// first-run onboarding ([OnboardingGate]) render their child immediately with
/// no overlay — so widget tests that pump the whole app see its content at once,
/// without waiting out the splash's (infinite) animation or dismissing
/// onboarding. **Never set this in production.**
bool debugDisableAppBootstrap = false;
