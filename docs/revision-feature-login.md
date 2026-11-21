# Auto-revisión propuesta: `feature/login` → `develop`

**Estado:** auto-revisión local documentada. Todavía no existe PR remoto porque este workspace no tiene un remoto de GitHub.

## Alcance revisado

- Registro e inicio de sesión por correo con Supabase Auth.
- Validación de correo y contraseña en el cliente.
- Manejo visible de errores del proveedor y del estado de confirmación de correo.
- Continuación local sin cuenta cuando Supabase no está configurado.
- Sin contraseñas ni claves `service_role` guardadas en el código.
- Sincronización limitada al usuario autenticado y protegida por políticas RLS; los tokens los administra Supabase.

## Comprobaciones

- `flutter analyze`: sin problemas.
- `flutter test`: pruebas de cifrado, persistencia SQLite y validación de formulario aprobadas.
- Configuración remota documentada en `README.md`; exige clave pública y políticas RLS antes de habilitar la sincronización.

## Resultado

La ruta local continúa disponible si Auth no está configurado o falla. El error de Auth se presenta en pantalla y no se simula un inicio de sesión exitoso. Al publicar, abrir un PR desde `feature/login` hacia `develop` y adjuntar esta revisión como auto-revisión; no se ha creado ni aprobado un PR en GitHub desde este workspace.
