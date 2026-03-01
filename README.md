# Kryptos

A post-quantum resistant password manager built for HackUDC, addressing the challenge proposed by Gradiant. This application combines classic industry standards (AES-GCM, Argon2id) with cutting-edge post-quantum cryptography (ML-KEM-768) to ensure long-term security.

## Purpose
In a future where quantum computers could break traditional asymmetric encryption, your stored secrets need a new layer of protection. Kryptos solves the "store now, decrypt later" threat by using a **hybrid encryption scheme** secure against both classical and quantum attacks.

Beyond storage, Kryptos addresses the root of security: the passwords themselves. It provides a **hardened password generation engine** designed to be as unpredictable as possible. By implementing **Cumulative Entropy Mixing**, the app mitigates common vulnerabilities where a random generator's seed might be guessed or known, ensuring that every generated secret is cryptographically robust.

## Features
- **Hybrid PQC Architecture**: Uses `liboqs` to implement NIST-standardized ML-KEM-768 (Kyber) alongside AES-256-GCM.
- **Hardened Generator**: Mitigates "Seed Attacks" by mixing multiple entropy sources (OS-level secure random, high-resolution system timestamps, and SHA-256 blit-whitening).
- **Zero-Knowledge Cloud Sync**: Securely synchronize your encrypted vault across devices using **Supabase**. Your master password and DEK never leave your device unencrypted.
- **Biometric Unlock**: Securely stores your vault key in the device's secure enclave (Keychain/Keystore) protected by biometrics.
- **Strong Key Derivation**: Uses Argon2id to derive master keys, providing industry-leading resistance against brute-force attempts.
- **Pwned Passwords Check**: Integrated with the "Have I Been Pwned" API to detect if your credentials have been exposed in known breaches.
- **Secure Export/Import**: Backup your vault using password-protected, authenticated encryption.
- **Automatic Lock**: Configurable timeout to protect data when the app is in the background.

## Installation
1. Ensure you have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
2. Clone this repository.
3. Run `flutter pub get` to fetch dependencies.
4. Ensure the `liboqs` binaries are correctly linked for your target platform (Android arm64/x86_64).
5. Run the app: `flutter run`

## Usage Examples
- **Creating a Vault**: Set a master password (minimum 12 characters, including uppercase, lowercase, numbers, and symbols). The app will check it against the RockYou breach list for your safety.
- **Generating Passwords**: Use the generator tab to create keys up to 64 characters long, backed by multi-source entropy.
- **Cloud Synchronization**: Log in with your Supabase account in Settings to enable real-time backup and multi-device sync.
- **Adding Entries**: Tap the '+' button, fill in details, and toggle "Require Master Password" for extra-sensitive accounts.
- **Revealing Passwords**: Tap the eye icon; if protected, it will request your master password or biometrics.

## Configuration
- **Auto-lock Timeout**: Configurable in Settings (Immediate, 30s, 1m, 5m, Never).
- **Biometrics**: Enable or disable in Settings (requires initial master password validation).

## Compatibility
- **Android**: 10.0+ (API 29+) recommended for Scoped Storage and Biometrics.

## Troubleshooting
- **liboqs errors**: Ensure your device architecture (arm64/x86_64) matches the provided shared libraries.
- **Permission Denied**: When exporting, use the system file picker to select a valid directory.

## Support Channels
For issues or questions related to this HackUDC challenge entry, please open an issue in this repository.
