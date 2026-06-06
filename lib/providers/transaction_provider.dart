import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';
import '../utils/date_utils.dart' as qx;

class TransactionProvider extends ChangeNotifier {
  List<Transaction> _transactions = [];
  List<Transaction> _expenseTransactions = [];
  Map<String, double> _summary = {'income': 0, 'expense': 0, 'balance': 0};
  bool _isLoading = false;
  DateTime _currentDate = qx.DateUtils.getBeijingTime();
  String _dateRangeType = 'month';
  int? _selectedCategoryId;
  String? _searchNote;
  DateTimeRange? _customDateRange;

  int? get selectedCategoryId => _selectedCategoryId;

  List<Transaction> get transactions => _transactions;
  List<Transaction> get expenseTransactions => _expenseTransactions;
  Map<String, double> get summary => _summary;
  bool get isLoading => _isLoading;
  DateTime get currentDate => _currentDate;
  String get dateRangeType => _dateRangeType;
  DateTimeRange? get customDateRange => _customDateRange;

  DateTimeRange get currentDateRange {
    if (_dateRangeType == 'custom' && _customDateRange != null) {
      return _customDateRange!;
    }
    switch (_dateRangeType) {
      case 'week':
        return DateTimeRange(
          start: qx.DateUtils.getStartOfWeek(_currentDate),
          end: qx.DateUtils.getEndOfWeek(_currentDate),
        );
      case 'year':
        return DateTimeRange(
          start: qx.DateUtils.getStartOfYear(_currentDate),
          end: qx.DateUtils.getEndOfYear(_currentDate),
        );
      case 'month':
      default:
        return DateTimeRange(
          start: qx.DateUtils.getStartOfMonth(_currentDate),
          end: qx.DateUtils.getEndOfMonth(_currentDate),
        );
    }
  }

  Future<void> loadTransactions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final range = currentDateRange;
      _transactions = await DatabaseService.instance.getTransactions(
        startDate: range.start,
        endDate: range.end,
        categoryId: _selectedCategoryId,
        searchNote: _searchNote,
      );
      _expenseTransactions = _transactions.where((t) => t.type == 'expense').toList();
      _summary = await DatabaseService.instance.getSummaryByDateRange(
        range.start,
        range.end,
      );
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTransaction(Transaction transaction) async {
    await DatabaseService.instance.insertTransaction(transaction);
    await loadTransactions();
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await DatabaseService.instance.updateTransaction(transaction);
    await loadTransactions();
  }

  Future<void> deleteTransaction(int id) async {
    await DatabaseService.instance.deleteTransaction(id);
    await loadTransactions();
  }

  void setDate(DateTime date) {
    _currentDate = date;
    notifyListeners();
    loadTransactions();
  }

  void setDateRangeType(String type) {
    _dateRangeType = type;
    if (type == 'month' || type == 'week' || type == 'year') {
      _currentDate = qx.DateUtils.getBeijingTime();
    }
    notifyListeners();
    loadTransactions();
  }

  void setCustomDateRange(DateTime start, DateTime end) {
    _dateRangeType = 'custom';
    _customDateRange = DateTimeRange(start: start, end: end);
    notifyListeners();
    loadTransactions();
  }

  void resetToCurrentDate() {
    _currentDate = qx.DateUtils.getBeijingTime();
    notifyListeners();
    loadTransactions();
  }

  void setFilter({int? categoryId, String? searchNote}) {
    _selectedCategoryId = categoryId;
    _searchNote = searchNote;
    notifyListeners();
    loadTransactions();
  }

  void clearFilter() {
    _selectedCategoryId = null;
    _searchNote = null;
    notifyListeners();
    loadTransactions();
  }

  void previousPeriod() {
    switch (_dateRangeType) {
      case 'week':
        _currentDate = _currentDate.subtract(const Duration(days: 7));
        break;
      case 'year':
        _currentDate = DateTime(_currentDate.year - 1, _currentDate.month);
        break;
      case 'month':
      default:
        _currentDate = DateTime(_currentDate.year, _currentDate.month - 1);
        break;
    }
    notifyListeners();
    loadTransactions();
  }

  void nextPeriod() {
    switch (_dateRangeType) {
      case 'week':
        _currentDate = _currentDate.add(const Duration(days: 7));
        break;
      case 'year':
        _currentDate = DateTime(_currentDate.year + 1, _currentDate.month);
        break;
      case 'month':
      default:
        _currentDate = DateTime(_currentDate.year, _currentDate.month + 1);
        break;
    }
    notifyListeners();
    loadTransactions();
  }
}
