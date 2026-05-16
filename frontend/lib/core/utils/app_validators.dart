class AppValidators {
  // 1. Validar que un campo no esté vacío
  static String? required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'El campo $fieldName es obligatorio.';
    }
    return null;
  }

  // 2. Validar formato de Email con Expresión Regular (RegEx)
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El correo electrónico es obligatorio.';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Por favor, introduce un correo electrónico válido.';
    }
    return null;
  }

  // 3. Validar Contraseña Segura (Mínimo 6 caracteres, letras y números)
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria.';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    // Opcional: Puedes agregar regex para exigir números o mayúsculas aquí
    return null;
  }

  // 4. Validar que dos campos coincidan (Ej: Confirmar contraseña)
  static String? match(String? value, String? targetValue, String errorMsg) {
    if (value != targetValue) {
      return errorMsg;
    }
    return null;
  }
}
