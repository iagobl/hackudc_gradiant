# HackUDC Gradiant Vault

A post-quantum resistant password manager built for HackUDC, addressing the challenge proposed by Gradiant. This application combines classic industry standards (AES-GCM, Argon2id) with cutting-edge post-quantum cryptography (ML-KEM-768) to ensure long-term security.

## Purpose
In a future where quantum computers could break traditional asymmetric encryption, your stored secrets need a new layer of protection. This project solves the "store now, decrypt later" threat by using a hybrid encryption scheme that is secure against both classical and quantum attacks.

## Features
- **Hybrid PQC Architecture**: Uses `liboqs` to implement NIST-standardized ML-KEM-768 alongside AES-256-GCM.
- **Biometric Unlock**: Securely store your vault key in the device's secure enclave (Keychain/Keystore).
- **Strong Key Derivation**: Uses Argon2id to derive master keys, preventing brute-force attacks.
- **Pwned Passwords Check**: Integration with "Have I Been Pwned" API to detect leaked credentials.
- **Secure Export/Import**: Backup your vault using password-protected, authenticated encryption.
- **Automatic Lock**: Configurable timeout to protect data when the app is in the background.

## Installation
1. Ensure you have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
2. Clone this repository.
3. Run `flutter pub get` to fetch dependencies.
4. (Optional) For PQC support, ensure the `liboqs` binaries are correctly linked for your target platform.
5. Run the app: `flutter run`

## Usage Examples
- **Creating a Vault**: Set a master password (min 12 chars, upper, lower, symbols).
- **Adding Entries**: Tap the '+' button, fill in details, and toggle "Require Master Password" for extra sensitive items.
- **revealing Passwords**: Tap the eye icon (may require master password or biometrics).
- **Exporting**: Go to Settings -> Bóveda -> Exportar Bóveda to save an encrypted `.vlt` backup.

## Configuration
- **Auto-lock Timeout**: Set in Settings (Immediate, 30s, 1m, 5m, Never).
- **Biometrics**: Enable/Disable in Settings (requires an initial master password validation).

## Compatibility
- **Android**: 10.0+ (API 29+) recommended for Scoped Storage and Biometrics.

## Troubleshooting
- **liboqs errors**: Ensure your device architecture (arm64/x86_64) matches the provided shared libraries.
- **Permission Denied**: When exporting, use the system file picker to select a valid directory.

## Support Channels
For issues or questions related to this HackUDC challenge entry, please open an issue in this repository.
