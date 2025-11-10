import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/screens/profile/profile_screen.dart';

/// FindHelperScreen — people-only search with helper-focused filters.
class FindHelperScreen extends StatefulWidget {
  const FindHelperScreen({Key? key}) : super(key: key);

  @override
  State<FindHelperScreen> createState() => _FindHelperScreenState();
}

class _FindHelperScreenState extends State<FindHelperScreen> {
  // —— Search + debounce
  final TextEditingController _q = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;

  // —— Filters
  final Set<String> _selectedCategories = {};
  final Set<String> _selectedLanguages  = {};
  bool _onlyAvailable = false;
  bool _onlyVerified  = false;
  double? _minPrice;
  double? _maxPrice;

  _Sort _sort = _Sort.relevance;

  // —— Data/result state
  bool _loading = true;
  List<_Helper> _all = [];
  List<_Helper> _hits = [];

  @override
  void initState() {
    super.initState();
    _q.addListener(_onQueryChanged);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.removeListener(_onQueryChanged);
    _q.dispose();
    _focus.dispose();
    super.dispose();
  }

  // —— Firestore fetch with a friendly fallback so you see data during setup
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [];

      // Primary: helpers only (kept exactly as-is)
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where('isHelper', isEqualTo: true)
            .limit(400)
            .get();
        docs = snap.docs;
      } catch (_) {}

      // Fallback: if none returned, pull a broader batch (NO extra filtering)
      if (docs.isEmpty) {
        try {
          final broad = await FirebaseFirestore.instance
              .collection('users')
              .limit(400)
              .get();
          docs = broad.docs;
        } catch (_) {}
      }

      final list = <_Helper>[];
      for (final d in docs) {
        final m = d.data();

        // Derive fields from onboarding-style keys when missing
        final List<String> categoriesRaw =
            (m['categories'] is List) ? List<String>.from(m['categories']) : const [];
        final List<String> interestTags =
            (m['interestTags'] is List) ? List<String>.from(m['interestTags']) : const [];
        final List<String> languagesRaw =
            (m['languages'] is List) ? List<String>.from(m['languages']) : const [];
        final String singleLanguage = (m['language'] ?? '').toString().trim();
        final String photo =
            (m['photoURL'] ?? m['avatar'] ?? m['profilePicture'] ?? '').toString();

        final List<String> categories =
            categoriesRaw.isNotEmpty ? categoriesRaw : interestTags;
        final List<String> languages =
            languagesRaw.isNotEmpty
                ? languagesRaw.map((e) => e.toString()).toList()
                : (singleLanguage.isNotEmpty ? <String>[singleLanguage] : <String>[]);

        final bool availableFlag = (m['isAvailable'] == true);
        final String availabilityStr = (m['availability'] ?? '').toString();
        final bool derivedAvailable = availabilityStr.isNotEmpty;

        final bool verifiedFlag = (m['isVerified'] == true);
        final bool badgesVerified = (m['badges'] is List) &&
            (m['badges'] as List).map((e) => e.toString().toLowerCase()).contains('verified');

        list.add(_Helper(
          id: d.id,
          name: (m['displayName'] ?? m['fullName'] ?? m['userName'] ?? 'User').toString(),
          handle: (m['userName'] ?? '').toString(),
          bio: (m['bio'] ?? '').toString(),
          avatar: photo,
          categories: categories.map((e) => e.toString()).toList(),
          languages: languages.map((e) => e.toString()).toList(),
          isAvailable: availableFlag || derivedAvailable,
          isVerified: verifiedFlag || badgesVerified,
          hourlyRate: _toDouble(m['hourlyRate']),
          rating: _toDouble(m['rating']) ?? 0.0,
          createdAt: m['createdAt'],
        ));
      }

      if (!mounted) return;
      setState(() {
        _all = list;
      });
      _applyFilters();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _all = [];
        _hits = [];
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _applyFilters);
    setState(() {}); // so the clear button reacts instantly
  }

  void _resetAll() {
    _q.clear();
    _selectedCategories.clear();
    _selectedLanguages.clear();
    _onlyAvailable = false;
    _onlyVerified = false;
    _minPrice = null;
    _maxPrice = null;
    _sort = _Sort.relevance;
    _applyFilters();
    setState(() {}); // update pills immediately
  }

  // —— Filtering + sorting
  void _applyFilters() {
    final query = _norm(_q.text.trim());
    List<_Helper> list = List.of(_all);

    // Text query (name/handle/bio)
    if (query.isNotEmpty) {
      list = list.where((h) {
        final hay = '${_norm(h.name)} ${_norm(h.handle)} ${_norm(h.bio)}';
        return hay.contains(query);
      }).toList();
    }

    // Availability / Verified
    if (_onlyAvailable) list = list.where((h) => h.isAvailable).toList();
    if (_onlyVerified)  list = list.where((h) => h.isVerified).toList();

    // Categories (subset match)
    if (_selectedCategories.isNotEmpty) {
      list = list.where((h) {
        final helperCats = h.categories.map(_norm).toSet();
        return _selectedCategories.every((c) => helperCats.contains(_norm(c)));
      }).toList();
    }

    // Languages (subset match)
    if (_selectedLanguages.isNotEmpty) {
      list = list.where((h) {
        final langs = h.languages.map(_norm).toSet();
        return _selectedLanguages.every((l) => langs.contains(_norm(l)));
      }).toList();
    }

    // Price range — exclude null prices whenever a bound is set
    if (_minPrice != null) {
      list = list.where((h) => h.hourlyRate != null && h.hourlyRate! >= _minPrice!).toList();
    }
    if (_maxPrice != null) {
      list = list.where((h) => h.hourlyRate != null && h.hourlyRate! <= _maxPrice!).toList();
    }

    // Sorting
    switch (_sort) {
      case _Sort.relevance:
        list.sort((a, b) {
          int score(_Helper h) {
            int s = 0;
            if (query.isNotEmpty) {
              final hay = '${_norm(h.name)} ${_norm(h.handle)} ${_norm(h.bio)}';
              if (hay.startsWith(query)) s += 3;
              if (hay.contains(' $query')) s += 2;
              if (hay.contains(query)) s += 1;
            }
            if (h.isVerified) s += 2;
            s += (h.rating * 10).round();
            return s;
          }
          return score(b).compareTo(score(a));
        });
        break;
      case _Sort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case _Sort.price:
        list.sort((a, b) => (a.hourlyRate ?? 1e9).compareTo(b.hourlyRate ?? 1e9));
        break;
      case _Sort.newest:
        int ms(_Helper h) {
          final t = _toDate(h.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);
          return t.millisecondsSinceEpoch;
        }
        list.sort((a, b) => ms(b).compareTo(ms(a)));
        break;
    }

    if (!mounted) return;
    setState(() => _hits = list);
  }

  // —— UI
  @override
  Widget build(BuildContext context) {
    final hasQuery = _q.text.trim().isNotEmpty;
    final anyFilterActive = hasQuery ||
        _selectedCategories.isNotEmpty ||
        _selectedLanguages.isNotEmpty ||
        _onlyAvailable ||
        _onlyVerified ||
        _minPrice != null ||
        _maxPrice != null ||
        _sort != _Sort.relevance;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        title: const Text('Find a helper'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (anyFilterActive)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _resetAll,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.text,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  backgroundColor: AppColors.card,
                ),
                child: const Text('Reset filters', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search + Clear
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: _SearchPill(
              controller: _q,
              focusNode: _focus,
              hint: 'Search helpers by name, bio, or handle…',
              showClear: hasQuery,
              onClear: () {
                _q.clear();
                _applyFilters();
                setState(() {});
              },
            ),
          ),

          // Filter rows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _FilterRow(
              selectedCategories: _selectedCategories,
              selectedLanguages: _selectedLanguages,
              onlyAvailable: _onlyAvailable,
              onlyVerified: _onlyVerified,
              minPrice: _minPrice,
              maxPrice: _maxPrice,
              sort: _sort,
              onChanged: ({
                Set<String>? categories,
                Set<String>? languages,
                bool? onlyAvailable,
                bool? onlyVerified,
                double? minPrice,
                double? maxPrice,
                _Sort? sort,
              }) {
                // Preserve every other value; apply what’s provided.
                if (categories != null) {
                  _selectedCategories
                    ..clear()
                    ..addAll(categories);
                }
                if (languages != null) {
                  _selectedLanguages
                    ..clear()
                    ..addAll(languages);
                }
                if (onlyAvailable != null) _onlyAvailable = onlyAvailable;
                if (onlyVerified  != null) _onlyVerified  = onlyVerified;

                // Always accept min/max (so Price → Clear truly clears)
                _minPrice = minPrice;
                _maxPrice = maxPrice;

                if (sort != null) _sort = sort;

                _applyFilters();
                setState(() {});
              },
            ),
          ),

          const SizedBox(height: 6),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _hits.isEmpty
                    ? const _EmptyState(text: 'No helpers match your filters.')
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                        itemCount: _hits.length,
                        itemBuilder: (_, i) => _HelperTile(helper: _hits[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

// —— Models ————————————————————————————————————————————————————————————
class _Helper {
  final String id;
  final String name;
  final String handle;
  final String bio;
  final String avatar;
  final List<String> categories;
  final List<String> languages;
  final bool isAvailable;
  final bool isVerified;
  final double? hourlyRate;
  final double rating;
  final dynamic createdAt;

  _Helper({
    required this.id,
    required this.name,
    required this.handle,
    required this.bio,
    required this.avatar,
    required this.categories,
    required this.languages,
    required this.isAvailable,
    required this.isVerified,
    required this.hourlyRate,
    required this.rating,
    required this.createdAt,
  });
}

// —— Tiles ————————————————————————————————————————————————————————————
class _HelperTile extends StatelessWidget {
  final _Helper helper;
  const _HelperTile({required this.helper});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => ProfileScreen(userID: helper.id)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(url: helper.avatar, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // name + verified badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            helper.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (helper.isVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.verified, color: AppColors.primary, size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (helper.handle.isNotEmpty)
                      Text('@${helper.handle}', style: const TextStyle(color: AppColors.muted)),
                    if (helper.handle.isNotEmpty) const SizedBox(height: 6),
                    if (helper.bio.isNotEmpty)
                      Text(
                        helper.bio,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.text, height: 1.3),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (helper.hourlyRate != null)
                          _Tag('\$${helper.hourlyRate!.toStringAsFixed(0)}/hr'),
                        if (helper.isAvailable) const _Tag('Available now'),
                        if (helper.categories.isNotEmpty)
                          ...helper.categories.take(3).map((c) => _Tag(c)),
                        if (helper.languages.isNotEmpty)
                          _Tag(helper.languages.take(2).join(' · ')),
                        if (helper.rating > 0)
                          _Tag('★ ${helper.rating.toStringAsFixed(1)}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);
  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.button,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
    );
  }
}

// —— Filter row ————————————————————————————————————————————————————————
enum _Sort { relevance, rating, price, newest }

class _FilterRow extends StatelessWidget {
  final Set<String> selectedCategories;
  final Set<String> selectedLanguages;
  final bool onlyAvailable;
  final bool onlyVerified;
  final double? minPrice;
  final double? maxPrice;
  final _Sort sort;

  final void Function({
    Set<String>? categories,
    Set<String>? languages,
    bool? onlyAvailable,
    bool? onlyVerified,
    double? minPrice,
    double? maxPrice,
    _Sort? sort,
  }) onChanged;

  const _FilterRow({
    Key? key,
    required this.selectedCategories,
    required this.selectedLanguages,
    required this.onlyAvailable,
    required this.onlyVerified,
    required this.minPrice,
    required this.maxPrice,
    required this.sort,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Helper to pass COPIES so parent mutations don't clear our local sets.
    Set<String> _copy(Set<String> s) => Set<String>.of(s);

    // —— First row (always single line, horizontally scrollable):
    final firstRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChipButton(
            icon: Icons.category_outlined,
            label: selectedCategories.isEmpty
                ? 'Category'
                : 'Category (${selectedCategories.length})',
            onTap: () async {
              final result = await _pickListSheet(
                context,
                title: 'Select categories',
                // Use onboarding categories
                options: const [
                  'Immigration',
                  'Moving to Canada',
                  'PR Pathways',
                  'Quebec-specific help',
                  'Job hunting',
                  'Refugee claim process',
                  'Student life',
                  'Parenting support',
                  'Language learning',
                ],
                initial: selectedCategories,
              );
              if (result != null) {
                onChanged(
                  categories: Set.of(result),
                  languages: _copy(selectedLanguages),
                  onlyAvailable: onlyAvailable,
                  onlyVerified: onlyVerified,
                  minPrice: minPrice,
                  maxPrice: maxPrice,
                  sort: sort,
                );
              }
            },
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            icon: Icons.language,
            label: selectedLanguages.isEmpty
                ? 'Language'
                : 'Language (${selectedLanguages.length})',
            onTap: () async {
              final result = await _pickListSheet(
                context,
                title: 'Select languages',
                // Use onboarding languages
                options: const ['English', 'French', 'Other'],
                initial: selectedLanguages,
              );
              if (result != null) {
                onChanged(
                  categories: _copy(selectedCategories),
                  languages: Set.of(result),
                  onlyAvailable: onlyAvailable,
                  onlyVerified: onlyVerified,
                  minPrice: minPrice,
                  maxPrice: maxPrice,
                  sort: sort,
                );
              }
            },
          ),
          const SizedBox(width: 8),
          _TogglePill(
            label: 'Available',
            value: onlyAvailable,
            onChanged: (v) => onChanged(
              categories: _copy(selectedCategories),
              languages: _copy(selectedLanguages),
              onlyAvailable: v,
              onlyVerified: onlyVerified,
              minPrice: minPrice,
              maxPrice: maxPrice,
              sort: sort,
            ),
          ),
        ],
      ),
    );

    // —— Second row
    final secondRow = Wrap(
      spacing: 8,
      runSpacing: 10,
      children: [
        _TogglePill(
          label: 'Verified',
          value: onlyVerified,
          onChanged: (v) => onChanged(
            categories: _copy(selectedCategories),
            languages: _copy(selectedLanguages),
            onlyAvailable: onlyAvailable,
            onlyVerified: v,
            minPrice: minPrice,
            maxPrice: maxPrice,
            sort: sort,
          ),
        ),
        _PricePill(
          minPrice: minPrice,
          maxPrice: maxPrice,
          onChanged: (min, max) => onChanged(
            categories: _copy(selectedCategories),
            languages: _copy(selectedLanguages),
            onlyAvailable: onlyAvailable,
            onlyVerified: onlyVerified,
            minPrice: min,
            maxPrice: max,
            sort: sort,
          ),
        ),
        _SortPill(
          current: sort,
          onChanged: (s) => onChanged(
            categories: _copy(selectedCategories),
            languages: _copy(selectedLanguages),
            onlyAvailable: onlyAvailable,
            onlyVerified: onlyVerified,
            minPrice: minPrice,
            maxPrice: maxPrice,
            sort: s,
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        firstRow,
        const SizedBox(height: 10),
        secondRow,
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _FilterChipButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.button,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.muted),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reworked to visually match `_FilterChipButton` so baselines line up.
class _TogglePill extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _TogglePill({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.button,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value) ...[
                const Icon(Icons.check, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  final double? minPrice;
  final double? maxPrice;
  final void Function(double? min, double? max) onChanged;
  const _PricePill({
    required this.minPrice,
    required this.maxPrice,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return _FilterChipButton(
      icon: Icons.attach_money,
      label: (minPrice == null && maxPrice == null)
          ? 'Price'
          : '\$${minPrice?.toStringAsFixed(0) ?? '0'}–\$${maxPrice?.toStringAsFixed(0) ?? '∞'}',
      onTap: () async {
        final res = await showModalBottomSheet<_PriceRange>(
          context: context,
          backgroundColor: AppColors.card,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          isScrollControlled: true,
          builder: (_) => _PriceSheet(min: minPrice, max: maxPrice),
        );
        if (res != null) onChanged(res.min, res.max);
      },
    );
  }
}

class _SortPill extends StatelessWidget {
  final _Sort current;
  final ValueChanged<_Sort> onChanged;
  const _SortPill({required this.current, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return _FilterChipButton(
      icon: Icons.sort,
      label: {
        _Sort.relevance: 'Relevance',
        _Sort.rating: 'Rating',
        _Sort.price: 'Price',
        _Sort.newest: 'Newest',
      }[current]!,
      onTap: () async {
        final res = await showModalBottomSheet<_Sort>(
          context: context,
          backgroundColor: AppColors.card,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          builder: (_) => _SortSheet(current: current),
        );
        if (res != null) onChanged(res);
      },
    );
  }
}

// —— Sheets ————————————————————————————————————————————————————————————
class _PriceRange {
  final double? min;
  final double? max;
  const _PriceRange(this.min, this.max);
}

class _PriceSheet extends StatefulWidget {
  final double? min;
  final double? max;
  const _PriceSheet({this.min, this.max});

  @override
  State<_PriceSheet> createState() => _PriceSheetState();
}

class _PriceSheetState extends State<_PriceSheet> {
  late final TextEditingController _min =
      TextEditingController(text: widget.min?.toStringAsFixed(0) ?? '');
  late final TextEditingController _max =
      TextEditingController(text: widget.max?.toStringAsFixed(0) ?? '');

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 18 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetGrabber(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _priceField(_min, 'Min')),
                const SizedBox(width: 12),
                Expanded(child: _priceField(_max, 'Max')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, const _PriceRange(null, null)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      foregroundColor: AppColors.text,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final min = double.tryParse(_min.text.trim());
                      final max = double.tryParse(_max.text.trim());
                      Navigator.pop(context, _PriceRange(min, max));
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _priceField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.button,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

class _SortSheet extends StatelessWidget {
  final _Sort current;
  const _SortSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    final items = <_Sort, String>{
      _Sort.relevance: 'Relevance',
      _Sort.rating: 'Rating',
      _Sort.price: 'Price (low → high)',
      _Sort.newest: 'Newest',
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetGrabber(),
            for (final e in items.entries)
              ListTile(
                title: Text(e.value),
                trailing: e.key == current ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(context, e.key),
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

// —— Pick-list sheet (multi-select, stateful) ————————————————
Future<Set<String>?> _pickListSheet(
  BuildContext context, {
  required String title,
  required List<String> options,
  required Set<String> initial,
}) {
  final temp = initial.map(_norm).toSet();
  return showModalBottomSheet<Set<String>>(
    context: context,
    backgroundColor: AppColors.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: Theme.of(ctx)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (_, i) {
                        final label = options[i];
                        final key = _norm(label);
                        final sel = temp.contains(key);
                        return CheckboxListTile(
                          value: sel,
                          onChanged: (v) {
                            if (v == true) {
                              temp.add(key);
                            } else {
                              temp.remove(key);
                            }
                            setSheetState(() {});
                          },
                          title: Text(label),
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.primary,
                          checkboxShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, null),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final Set<String> out = {};
                          for (final o in options) {
                            if (temp.contains(_norm(o))) out.add(o);
                          }
                          Navigator.pop(ctx, out);
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  )
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

// —— UI atoms ————————————————————————————————————————————————————————————
class _SearchPill extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool showClear;
  final VoidCallback onClear;

  const _SearchPill({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.showClear,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.button,
      borderRadius: BorderRadius.circular(28),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                hintText: 'Search helpers…',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {},
            ),
          ),
          if (showClear)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.muted),
              onPressed: onClear,
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final double radius;
  const _Avatar({required this.url, this.radius = 20});
  @override
  Widget build(BuildContext context) => url.isEmpty
      ? CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.avatarBg,
          child: const Icon(Icons.person_outline, color: AppColors.avatarFg),
        )
      : CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
}

// —— Helpers ————————————————————————————————————————————————————————————
double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

DateTime? _toDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

String _norm(String s) {
  final lower = s.toLowerCase();
  const Map<String, String> repl = {
    // Turkish
    'ı': 'i', 'ğ': 'g', 'ş': 's', 'ç': 'c', 'ö': 'o', 'ü': 'u',
    // Common Latin
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'û': 'u',
    'ñ': 'n',
  };
  final buf = StringBuffer();
  for (final cp in lower.runes) {
    final ch = String.fromCharCode(cp);
    buf.write(repl[ch] ?? ch);
  }
  return buf.toString().trim();
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({this.text = 'No results.'});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Center(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
