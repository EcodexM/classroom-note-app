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
    this.hintText = 'Search...',
  }) : super(key: key);

  @override
  _SearchWidgetState createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSubject = '';
  String _selectedSortOption = '';
  bool _isFilterExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showFilterOptions() {
    // Test Case 2.2 - Filter by Subject
    // Test Case 2.3 - Combined Filter and Sort by Rating
    setState(() {
      _isFilterExpanded = !_isFilterExpanded;
    });

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Filter & Sort',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 20),

                  // Subject Filter
                  Text(
                    'Subject',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip('All', '', setModalState),
                      _buildFilterChip('Physics', 'Physics', setModalState),
                      _buildFilterChip(
                        'Mathematics',
                        'Mathematics',
                        setModalState,
                      ),
                      _buildFilterChip(
                        'Computer Science',
                        'Computer Science',
                        setModalState,
                      ),
                      _buildFilterChip('Biology', 'Biology', setModalState),
                      _buildFilterChip('History', 'History', setModalState),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Sort Options
                  Text(
                    'Sort By',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildSortChip('Latest', 'latest', setModalState),
                      _buildSortChip('Oldest', 'oldest', setModalState),
                      _buildSortChip(
                        'Highest Rating',
                        'highest_rating',
                        setModalState,
                      ),
                      _buildSortChip(
                        'Most Downloaded',
                        'most_downloaded',
                        setModalState,
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);

                        // Combine filter and sort options
                        final filterOptions = {
                          'subject': _selectedSubject,
                          'sort': _selectedSortOption,
                        };

                        if (widget.onFilter != null) {
                          widget.onFilter!(filterOptions.toString());
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    StateSetter setModalState,
  ) {
    return FilterChip(
      label: Text(label),
      selected: _selectedSubject == value,
      onSelected: (selected) {
        setModalState(() {
          _selectedSubject = selected ? value : '';
        });
      },
      selectedColor: Colors.deepPurple.withOpacity(0.3),
      backgroundColor: Colors.grey.withOpacity(0.1),
      labelStyle: TextStyle(
        color: _selectedSubject == value ? Colors.deepPurple : Colors.black87,
        fontFamily: 'Poppins',
      ),
    );
  }

  Widget _buildSortChip(String label, String value, StateSetter setModalState) {
    return FilterChip(
      label: Text(label),
      selected: _selectedSortOption == value,
      onSelected: (selected) {
        setModalState(() {
          _selectedSortOption = selected ? value : '';
        });
      },
      selectedColor: Colors.deepPurple.withOpacity(0.3),
      backgroundColor: Colors.grey.withOpacity(0.1),
      labelStyle: TextStyle(
        color:
            _selectedSortOption == value ? Colors.deepPurple : Colors.black87,
        fontFamily: 'Poppins',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          // Test Case 2.1 - Search by Keyword
          widget.onSearch(value);

          // Test Case 2.4 - Search With No Match (handled in parent widget)
        },
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          hintText: widget.hintText,
          hintStyle: TextStyle(color: Colors.grey, fontFamily: 'Poppins'),
          suffixIcon:
              widget.showFilterButton
                  ? IconButton(
                    icon: Icon(
                      Icons.filter_list,
                      color:
                          _isFilterExpanded ? Colors.deepPurple : Colors.grey,
                    ),
                    onPressed: _showFilterOptions,
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}
