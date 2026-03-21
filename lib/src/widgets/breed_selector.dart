import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../models/breed_standard.dart';
import '../services/breed/breed_service.dart';
import '../theme/colors.dart';

/// Searchable breed selector widget
///
/// Usage:
/// ```dart
/// BreedSelector(
///   selectedBreedId: _breedId,
///   selectedBreedDisplayName: _breedName,
///   onBreedSelected: (breed) {
///     setState(() {
///       _breedId = breed?.id;
///       _breedName = breed?.displayName;
///     });
///   },
///   hintText: 'Select breed',
///   otherOptionText: 'Other (not listed)',
/// )
/// ```
class BreedSelector extends StatefulWidget {
  /// Currently selected breed ID
  final String? selectedBreedId;

  /// Display name of selected breed (for showing without re-fetching)
  final String? selectedBreedDisplayName;

  /// Callback when breed is selected (null if "Other" is selected)
  final ValueChanged<BreedStandard?> onBreedSelected;

  /// Hint text shown when nothing is selected
  final String hintText;

  /// Text for "Other" option at bottom of list
  final String otherOptionText;

  const BreedSelector({
    super.key,
    this.selectedBreedId,
    this.selectedBreedDisplayName,
    required this.onBreedSelected,
    this.hintText = 'Select breed',
    this.otherOptionText = 'Other (not listed)',
  });

  @override
  State<BreedSelector> createState() => _BreedSelectorState();
}

class _BreedSelectorState extends State<BreedSelector> {
  @override
  Widget build(BuildContext context) {
    final hasSelection = widget.selectedBreedId != null;

    final borderColor = hasSelection ? AppColors.brandPrimary : AppColors.warmGray;

    return GestureDetector(
      onTap: _openBreedDialog,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hasSelection
                    ? widget.selectedBreedDisplayName ?? widget.hintText
                    : widget.hintText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: hasSelection
                      ? AppColors.nearBlack
                      : AppColors.warmGray,
                  letterSpacing: -0.35,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: hasSelection ? AppColors.brandPrimary : AppColors.warmGray,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openBreedDialog() {
    showDialog(
      context: context,
      builder: (context) => _BreedSearchDialog(
        onBreedSelected: widget.onBreedSelected,
        otherOptionText: widget.otherOptionText,
      ),
    );
  }
}

/// Internal dialog for searching and selecting breeds
class _BreedSearchDialog extends StatefulWidget {
  final ValueChanged<BreedStandard?> onBreedSelected;
  final String otherOptionText;

  const _BreedSearchDialog({
    required this.onBreedSelected,
    required this.otherOptionText,
  });

  @override
  State<_BreedSearchDialog> createState() => _BreedSearchDialogState();
}

class _BreedSearchDialogState extends State<_BreedSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<BreedStandard> _allBreeds = [];
  List<BreedStandard> _filteredBreeds = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBreeds();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadBreeds() async {
    setState(() => _isLoading = true);

    try {
      final breeds = await BreedService.instance.fetchBreedStandards();
      if (mounted) {
        setState(() {
          _allBreeds = breeds;
          _filteredBreeds = breeds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredBreeds = _allBreeds;
      } else {
        _filteredBreeds = _allBreeds.where((breed) {
          return breed.displayName.toLowerCase().contains(query) ||
              breed.speciesCategory.toLowerCase().contains(query) ||
              (breed.breedVariant?.toLowerCase().contains(query) ?? false);
        }).toList();
      }
    });
  }

  void _selectBreed(BreedStandard? breed) {
    Navigator.of(context).pop();
    widget.onBreedSelected(breed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogHeight = screenHeight * 0.75;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        height: dialogHeight,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.breed_selectTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.nearBlack,
                      height: 1.4,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.gray600),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search field
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: l10n.breed_searchHint,
                hintStyle: const TextStyle(
                  fontSize: 16,
                  color: AppColors.gray500,
                  height: 1.5,
                  letterSpacing: 0.5,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.gray500,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: AppColors.gray500,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _searchFocusNode.requestFocus();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.gray300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.gray300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.brandPrimary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.nearBlack,
                height: 1.5,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),

            // Breed list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.brandPrimary,
                        ),
                      ),
                    )
                  : _filteredBreeds.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _searchQuery.isEmpty
                                  ? l10n.breed_noBreeds
                                  : l10n.breed_notFound,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.gray500,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildOtherOption(),
                          ],
                        )
                      : ListView.separated(
                          itemCount: _filteredBreeds.length + 1,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            color: AppColors.gray300,
                          ),
                          itemBuilder: (context, index) {
                            // "Other" option at the end
                            if (index == _filteredBreeds.length) {
                              return _buildOtherOption();
                            }

                            final breed = _filteredBreeds[index];
                            return _buildBreedItem(breed);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreedItem(BreedStandard breed) {
    final weightRange =
        '${breed.weightIdealMinG.toStringAsFixed(0)}-${breed.weightIdealMaxG.toStringAsFixed(0)}g';

    return InkWell(
      onTap: () => _selectBreed(breed),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    breed.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.nearBlack,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        breed.speciesCategory,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.gray600,
                          height: 1.4,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '•',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.gray500,
                          ),
                        ),
                      ),
                      Text(
                        weightRange,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.gray600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.gray500,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherOption() {
    return InkWell(
      onTap: () => _selectBreed(null),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.gray300, width: 2),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.add_circle_outline,
              color: AppColors.brandPrimary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.otherOptionText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.brandPrimary,
                  height: 1.5,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.brandPrimary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
