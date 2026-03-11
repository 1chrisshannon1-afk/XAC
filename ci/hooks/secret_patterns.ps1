# XAC Shared secret-detection patterns for pre-commit and pre-push hooks.
# Dot-source this file from hook scripts.

# Regex patterns for password, api_key, secret_key, token (capturing group for value)
$script:SecretPatterns = @(
    'password\s*=\s*["''`]([^"''`]{8,})["''`]',
    'api[_-]?key\s*=\s*["''`]([^"''`]{10,})["''`]',
    'secret[_-]?key\s*=\s*["''`]([^"''`]{10,})["''`]',
    'token\s*=\s*["''`]([^"''`]{10,})["''`]'
)

# Path patterns to skip (test files, docs, runbooks, known safe files)
$script:SecretSkipPatterns = @(
    '_archive[\\/]',
    '_ARCHIVE[\\/]',
    '\.test\.(tsx?|jsx?)$',
    'test_secret',
    'secret_manager',
    'README\.md$',
    'repo_docs[\\/]',
    'secret_names\.py'
)

# Regex for placeholder/safe values to ignore when a secret pattern matches
$script:SecretValueSkipPatterns = '^\$|^\{|placeholder|your_|example\.com|localhost|^test_|^mock_|^secret_|^conn_|^stored_|^sk_test_|^sk_live_|^pk_test_|^pk_live_|^whsec_|test-jwt-secret|test-secret-key|at-least-32|32-char|your-.+-key|your_.+_key'
