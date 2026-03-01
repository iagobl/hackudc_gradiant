# Kryptos

Un gestor de contraseñas resistente a la computación cuántica creado para el HackUDC, respondiendo al reto propuesto por Gradiant. Esta aplicación combina estándares clásicos de la industria (AES-GCM, Argon2id) con criptografía post-cuántica de vanguardia (ML-KEM-768) para garantizar la seguridad a largo plazo.

## Propósito
En un futuro donde los ordenadores cuánticos podrían romper el cifrado asimétrico tradicional, tus secretos almacenados necesitan una nueva capa de protección. Kryptos resuelve la amenaza de "almacenar ahora, descifrar después" mediante un **esquema de cifrado híbrido** seguro tanto contra ataques clásicos como cuánticos.

Más allá del almacenamiento, Kryptos aborda la raíz de la seguridad: las propias contraseñas. Proporciona un **motor de generación de contraseñas endurecido**, diseñado para ser lo más impredecible posible. Al implementar una **Mezcla de Entropía Acumulativa**, la aplicación mitiga vulnerabilidades comunes donde la semilla de un generador aleatorio podría ser adivinada o conocida, asegurando que cada secreto generado sea criptográficamente robusto.

## Características
- **Arquitectura PQC Híbrida**: Utiliza `liboqs` para implementar ML-KEM-768 (Kyber), estandarizado por el NIST, junto con AES-256-GCM.
- **Generador Endurecido**: Mitiga los "Ataques de Semilla" mezclando múltiples fuentes de entropía (aleatorio seguro del SO, marcas de tiempo del sistema de alta resolución y blanqueo SHA-256).
- **Sincronización en la Nube de Conocimiento Cero**: Sincroniza de forma segura tu bóveda cifrada entre dispositivos usando **Supabase**. Tu contraseña maestra y la DEK nunca abandonan tu dispositivo sin cifrar.
- **Desbloqueo Biométrico**: Almacena de forma segura la clave de tu bóveda en el enclave seguro del dispositivo (Keychain/Keystore) protegido por biometría.
- **Derivación de Claves Fuerte**: Utiliza Argon2id para derivar claves maestras, proporcionando una resistencia líder en la industria contra intentos de fuerza bruta.
- **Comprobación de Contraseñas Filtradas**: Integrado con la API "Have I Been Pwned" para detectar si tus credenciales han sido expuestas en filtraciones conocidas.
- **Exportación/Importación Segura**: Realiza copias de seguridad de tu bóveda mediante cifrado autenticado y protegido por contraseña.
- **Bloqueo Automático**: Tiempo de espera configurable en segundo plano para asegurar que tus datos permanezcan protegidos incluso si olvidas bloquear la aplicación.

## Instalación
1. Asegúrate de tener instalado el [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Clona este repositorio.
3. Ejecuta `flutter pub get` para obtener las dependencias.
4. Asegúrate de que los binarios de `liboqs` estén correctamente vinculados para tu plataforma de destino (Android arm64/x86_64).
5. Ejecuta la aplicación: `flutter run`

## Ejemplos de Uso
- **Crear una Bóveda**: Establece una contraseña maestra (mínimo 12 caracteres, incluyendo mayúsculas, minúsculas, números y símbolos). La aplicación la contrastará con la lista de filtraciones RockYou para tu seguridad.
- **Generar Contraseñas**: Usa la pestaña del generador para crear claves de hasta 64 caracteres, respaldadas por entropía de múltiples fuentes.
- **Sincronización en la Nube**: Inicia sesión con tu cuenta de Supabase en Ajustes para activar el respaldo en tiempo real y la sincronización multidispositivo.
- **Añadir Entradas**: Pulsa el botón '+', rellena los detalles y activa "Requerir Contraseña Maestra" para cuentas extra sensibles.
- **Revelar Contraseñas**: Toca el icono del ojo; si está protegida, solicitará tu contraseña maestra o biometría.

## Configuración
- **Tiempo de Bloqueo Automático**: Configurable en Ajustes (Inmediato, 30s, 1m, 5m, Nunca).
- **Biometría**: Activa o desactiva en Ajustes (requiere una validación inicial de la contraseña maestra).

## Compatibilidad
- **Android**: 10.0+ (API 29+) recomendado para Scoped Storage y soporte avanzado de biometría.

## Solución de Problemas
- **Errores de liboqs**: Asegúrate de que la arquitectura de tu dispositivo coincida con las librerías compartidas proporcionadas.
- **Permiso Denegado**: Al exportar, la aplicación utiliza el selector de archivos del sistema para asegurar un acceso seguro al directorio.

## Canales de Soporte
Para problemas o preguntas relacionadas con esta participación en el reto HackUDC, por favor abre un "Issue" en este repositorio.
