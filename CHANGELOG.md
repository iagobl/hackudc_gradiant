# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 01-03-2026

### Added
- Initial release for HackUDC challenge.
- Post-Quantum Cryptography (ML-KEM-768) integration via liboqs.
- Hybrid encryption scheme (PQC + Classical AES-GCM).
- Argon2id key derivation for master password.
- Biometric unlock support.
- Secure import/export of vault data.
- Automated vault locking on background/timeout.
- Pwned passwords integration.
- Password generator with cumulative entropy.
- Clean Architecture implementation for settings and vault modules.
