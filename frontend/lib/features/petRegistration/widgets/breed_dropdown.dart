import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';
import '../../../core/utils/app_validators.dart';

class BreedDropdown extends StatefulWidget {
  final Function(String) onBreedSelected;
  final String? initialBreed;

  const BreedDropdown({
    super.key,
    required this.onBreedSelected,
    this.initialBreed,
  });

  @override
  State<BreedDropdown> createState() => _BreedDropdownState();
}

class _BreedDropdownState extends State<BreedDropdown> {
  final List<String> commonBreeds = [
    'Mestizo',
    'Labrador Retriever',
    'Golden Retriever',
    'Pastor Alemán',
    'Chihuahua',
    'Yorkshire Terrier',
    'Bulldog Francés',
    'Chow-Chow',
    'Schnauzer',
    'Cocker Spaniel',
    'Beagle',
    'Boxer',
    'Rottweiler',
    'Dálmata',
    'Pug',
    'Otro (escribir)',
  ];

  late List<String> filteredBreeds;
  String? selectedBreed;
  final TextEditingController searchController = TextEditingController();
  final TextEditingController customBreedController = TextEditingController();
  bool showCustomBreedInput = false;

  @override
  void initState() {
    super.initState();
    filteredBreeds = commonBreeds;
    selectedBreed = widget.initialBreed;
    if (selectedBreed == 'Otro (escribir)') {
      showCustomBreedInput = true;
    }
  }

  void _filterBreeds(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredBreeds = commonBreeds;
      } else {
        filteredBreeds = commonBreeds
            .where((breed) =>
                breed.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _selectBreed(String breed) {
    if (breed == 'Otro (escribir)') {
      setState(() {
        selectedBreed = breed;
        showCustomBreedInput = true;
        searchController.clear();
        filteredBreeds = commonBreeds;
      });
    } else {
      setState(() {
        selectedBreed = breed;
        showCustomBreedInput = false;
        searchController.clear();
        filteredBreeds = commonBreeds;
      });
      widget.onBreedSelected(breed);
      Navigator.pop(context);
    }
  }

  void _confirmCustomBreed() {
    final customBreed = customBreedController.text.trim();
    final error = AppValidators.customBreed(customBreed);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppColors.panicRed,
        ),
      );
      return;
    }

    setState(() {
      selectedBreed = customBreed;
      showCustomBreedInput = false;
    });
    widget.onBreedSelected(customBreed);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        // FIX: limitar altura máxima del dialog
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text(
                'Selecciona la raza',
                style: AppTheme.headlineMd,
              ),
            ),

            // Search field o Custom input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: !showCustomBreedInput
                  ? TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Buscar raza...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: _filterBreeds,
                      style: AppTheme.bodyMd,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: customBreedController,
                          decoration: const InputDecoration(
                            hintText: 'Ej: Dogo Argentino',
                            labelText: 'Nombre de la raza',
                          ),
                          onChanged: (_) => setState(() {}),
                          style: AppTheme.bodyMd,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  showCustomBreedInput = false;
                                  customBreedController.clear();
                                  selectedBreed = null;
                                });
                              },
                              child: Text('Atrás', style: AppTheme.labelLg),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: customBreedController.text.isNotEmpty
                                  ? _confirmCustomBreed
                                  : null,
                              child: Text('Confirmar', style: AppTheme.labelLg.copyWith(color: Colors.white)),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 12),

            // Breed list
            if (!showCustomBreedInput)
              Flexible(
                // FIX: usar Flexible en lugar de Container con altura fija
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredBreeds.length,
                  itemBuilder: (context, index) {
                    final breed = filteredBreeds[index];
                    final isSelected = selectedBreed == breed;

                    return ListTile(
                      title: Text(breed, style: AppTheme.bodyMd),
                      trailing: isSelected
                          ? Icon(Icons.check, color: AppColors.esmeraldGreen)
                          : null,
                      onTap: () => _selectBreed(breed),
                      tileColor: isSelected
                          ? AppColors.esmeraldGreen.withValues(alpha: 0.1)
                          : null,
                    );
                  },
                ),
              ),

            // Close button
            if (!showCustomBreedInput)
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancelar', style: AppTheme.labelLg),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    customBreedController.dispose();
    super.dispose();
  }
}

// ── Widget que envuelve el dropdown ─────────────────────────────────

class BreedField extends StatefulWidget {
  final String? initialBreed;
  final Function(String) onBreedSelected;

  const BreedField({
    super.key,
    this.initialBreed,
    required this.onBreedSelected,
  });

  @override
  State<BreedField> createState() => _BreedFieldState();
}

class _BreedFieldState extends State<BreedField> {
  late String? selectedBreed;

  @override
  void initState() {
    super.initState();
    selectedBreed = widget.initialBreed;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => BreedDropdown(
            initialBreed: selectedBreed,
            onBreedSelected: (breed) {
              setState(() => selectedBreed = breed);
              widget.onBreedSelected(breed);
            },
          ),
        );
      },
      child: AbsorbPointer(
        child: TextFormField(
          decoration: const InputDecoration(
            labelText: 'Raza',
            hintText: 'Selecciona una raza',
            suffixIcon: Icon(Icons.arrow_drop_down),
          ),
          controller: TextEditingController(text: selectedBreed ?? ''),
          style: AppTheme.bodyMd,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'La raza es obligatoria';
            }
            return null;
          },
        ),
      ),
    );
  }
}