import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSearchPressed;
  final VoidCallback? onClearPressed;

  const SearchBarWidget({
    super.key,
    required this.controller,
    this.hintText = 'Search videos...',
    required this.onSearchPressed,
    this.onClearPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  onClearPressed?.call();
                },
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onSubmitted: (_) => onSearchPressed(),
      onChanged: (_) {
        // Trigger rebuild to show/hide clear button
      },
    );
  }
}

class GenreChipWidget extends StatelessWidget {
  final String genre;
  final bool isSelected;
  final VoidCallback onTap;

  const GenreChipWidget({
    super.key,
    required this.genre,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(genre),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.grey.shade900,
      selectedColor: Theme.of(context).primaryColor,
    );
  }
}
