import 'package:flutter/material.dart';

class SearchWidget extends StatefulWidget {
  final Function(String) onSearch;
  final Function(String)? onFilter;
  final bool showFilterButton;
  final String hintText;

  const SearchWidget({
    Key? key,
    required this.onSearch,
    this.onFilter,
    this.showFilterButton = true,
    this.hintText = 'Search your notes...',
  }) : super(key: key);

  @override
  _SearchWidgetState createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSubject = '';
  String _selectedSortOption = '';
  bool _isFilterVisible = false;

  // Modern color scheme
  final Color primaryColor = const Color(0xFF4E7CF6); // Modern blue
  final Color secondaryColor = const Color(0xFF8E24AA); // Purple accent
  final Color backgroundColor = const Color(0xFFF8F9FC); // Light background
  final Color cardColor = Colors.white;
  final Color textColor = const Color(0xFF2D3142); // Dark text
  final Color subtleTextColor = const Color(0xFF9E9E9E); // Subtle text

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleFilterVisibility() {
    setState(() {
      _isFilterVisible = !_isFilterVisible;
    });
  }

  void _applyFilters() {
    // Combine filter and sort options
    final filterOptions = {
      'subject': _selectedSubject,
      'sort': _selectedSortOption,
    };

    if (widget.onFilter != null) {
      widget.onFilter!(filterOptions.toString());
    }
  }

  Widget _buildSubjectFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 16, bottom: 12),
          child: Text(
            'Subject',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
              color: textColor,
              letterSpacing: 0.3,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildFilterChip('All', ''),
              SizedBox(width: 10),
              _buildFilterChip('Physics', 'Physics'),
              SizedBox(width: 10),
              _buildFilterChip('Mathematics', 'Mathematics'),
              SizedBox(width: 10),
              _buildFilterChip('Computer Science', 'Computer Science'),
              SizedBox(width: 10),
              _buildFilterChip('Biology', 'Biology'),
              SizedBox(width: 10),
              _buildFilterChip('History', 'History'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSortOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 20, bottom: 12),
          child: Text(
            'Sort By',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
              color: textColor,
              letterSpacing: 0.3,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildSortChip('Latest', 'latest'),
              SizedBox(width: 10),
              _buildSortChip('Oldest', 'oldest'),
              SizedBox(width: 10),
              _buildSortChip('Highest Rating', 'highest_rating'),
              SizedBox(width: 10),
              _buildSortChip('Most Downloaded', 'most_downloaded'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedSubject == value;
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : textColor,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedSubject = selected ? value : '';
          });
        },
        selectedColor: primaryColor,
        backgroundColor:
            isSelected ? primaryColor.withOpacity(0.8) : backgroundColor,
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? primaryColor : Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: isSelected ? 2 : 0,
        shadowColor:
            isSelected ? primaryColor.withOpacity(0.3) : Colors.transparent,
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _selectedSortOption == value;
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : textColor,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedSortOption = selected ? value : '';
          });
        },
        selectedColor: secondaryColor,
        backgroundColor:
            isSelected ? secondaryColor.withOpacity(0.8) : backgroundColor,
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? secondaryColor : Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: isSelected ? 2 : 0,
        shadowColor:
            isSelected ? secondaryColor.withOpacity(0.3) : Colors.transparent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Icon(Icons.search, color: subtleTextColor, size: 22),
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: widget.onSearch,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      color: subtleTextColor,
                      fontFamily: 'Poppins',
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                  ),
                ),
              ),
              if (widget.showFilterButton)
                Container(
                  margin: EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color:
                        _isFilterVisible
                            ? primaryColor.withOpacity(0.1)
                            : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.tune,
                      color: _isFilterVisible ? primaryColor : subtleTextColor,
                      size: 22,
                    ),
                    onPressed: _toggleFilterVisibility,
                    tooltip: 'Filter',
                  ),
                ),
            ],
          ),
        ),

        // Filter area (green highlighted area in the image)
        if (_isFilterVisible)
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 15,
                  spreadRadius: 0,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list, color: primaryColor, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Filter & Sort',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          color: primaryColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  color: Colors.grey.withOpacity(0.15),
                  thickness: 1,
                  indent: 20,
                  endIndent: 20,
                ),
                _buildSubjectFilter(),
                _buildSortOptions(),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        _applyFilters();
                        setState(() {
                          _isFilterVisible = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Apply Filters',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
