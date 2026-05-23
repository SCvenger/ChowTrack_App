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

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Por favor, introduce un correo electrónico válido.';
    }
    return null;
  }

  // 3. Validar Username 
  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre de usuario es obligatorio.';
    }

    if (value.trim().length < 3) {
      return 'Mínimo 3 caracteres.';
    }

    if (value.trim().length > 20) {
      return 'Máximo 20 caracteres.';
    }

    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(value.trim())) {
      return 'Solo letras, números y guiones bajos.';
    }

    return null;
  }

  // 4. Validar Contraseña Segura 
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria.';
    }

    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }

    // Validar que contenga al menos una letra
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
      return 'Debe contener al menos una letra.';
    }

    // Validar que contenga al menos un número
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Debe contener al menos un número.';
    }

    return null;
  }

  // 5. Validar que dos campos coincidan 
  static String? match(String? value, String? targetValue, String errorMsg) {
    if (value != targetValue) {
      return errorMsg;
    }
    return null;
  }

  // 6. Validar identidad 
  static String? identity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio.';
    }

    // Si contiene @, validamos como email
    if (value.contains('@')) {
      return email(value);
    }

    // Si no, validamos como username
    return username(value);
  }

  // ── Validadores específicos del wizard de mascotas ────────────────

  // 7. Validar nombre de mascota
  static String? petName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre es obligatorio';
    }

    // Solo letras, espacios y guiones
    final validChars = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s\-]+$');
    if (!validChars.hasMatch(value.trim())) {
      return 'Solo letras, espacios y guiones';
    }

    if (value.trim().length < 2) {
      return 'Mínimo 2 caracteres';
    }

    if (value.trim().length > 50) {
      return 'Máximo 50 caracteres';
    }

    return null;
  }

  // 8. Validar edad de mascota
  static String? petAge(String? value) {
    if (value == null || value.isEmpty) {
      return 'La edad es obligatoria';
    }

    final age = int.tryParse(value);

    if (age == null) {
      return 'Ingresa un número válido';
    }

    if (age < 0) {
      return 'La edad no puede ser negativa';
    }

    if (age > 30) {
      return 'Edad máxima: 30 años';
    }

    return null;
  }

  // 9. Validar raza personalizada
  static String? customBreed(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Escribe la raza de tu mascota';
    }

    // Solo letras y espacios (sin números)
    final validChars = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$');
    if (!validChars.hasMatch(value.trim())) {
      return 'Solo letras y espacios';
    }

    if (value.trim().length < 3) {
      return 'Mínimo 3 caracteres';
    }

    if (value.trim().length > 50) {
      return 'Máximo 50 caracteres';
    }

    return null;
  }

  // 10. Validar número de teléfono Bolivia
  static String? phoneBolivia(String? value) {
    // Opcional en MVP
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    // Remover espacios y guiones
    final cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');

    // Bolivia: 8 dígitos, empieza con 6, 7 u 8
    final validPhone = RegExp(r'^[678]\d{7}$');

    if (!validPhone.hasMatch(cleaned)) {
      return 'Número inválido (ej: 71234567)';
    }

    return null;
  }
}