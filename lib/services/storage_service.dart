import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';

class StorageService {
  static StorageService? _storageService;
  static SharedPreferences? _prefs;

  StorageService._internal();

  factory StorageService() {
    _storageService ??= StorageService._internal();
    return _storageService!;
  }

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // USER OPERATIONS
  Future<UserModel?> getUser() async {
    try {
      final preferences = await prefs;
      final userJson = preferences.getString('user');

      if (userJson != null && userJson.isNotEmpty) {
        final userMap = jsonDecode(userJson);
        return UserModel.fromMap(userMap);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  Future<bool> saveUser(String name) async {
    try {
      final preferences = await prefs;
      final existingUser = await getUser();
      final now = DateTime.now().toIso8601String();

      final userMap = existingUser != null
          ? {
              'id': existingUser.id,
              'name': name,
              'created_at': existingUser.createdAt.toIso8601String(),
              'updated_at': now,
            }
          : {'name': name, 'created_at': now, 'updated_at': now};

      return await preferences.setString('user', jsonEncode(userMap));
    } catch (e) {
      print('Error saving user: $e');
      return false;
    }
  }

  // TRANSACTION OPERATIONS
  Future<List<TransactionModel>> getTransactions() async {
    try {
      final preferences = await prefs;
      final transactionsJson = preferences.getStringList('transactions') ?? [];

      return await compute(_parseTransactions, transactionsJson);
    } catch (e) {
      print('Error getting transactions: $e');
      return [];
    }
  }

  static List<TransactionModel> _parseTransactions(
    List<String> transactionsJson,
  ) {
    return transactionsJson
        .map((json) => TransactionModel.fromMap(jsonDecode(json)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<bool> addTransaction(TransactionModel transaction) async {
    try {
      final preferences = await prefs;
      final transactions = await getTransactions();

      // Add new transaction with ID
      final newTransaction = transaction.copyWith(
        id: transactions.isEmpty ? 1 : transactions.last.id! + 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      transactions.add(newTransaction);

      final transactionsJson = transactions
          .map((t) => jsonEncode(t.toMap()))
          .toList();

      return await preferences.setStringList('transactions', transactionsJson);
    } catch (e) {
      print('Error adding transaction: $e');
      return false;
    }
  }

  Future<bool> updateTransaction(TransactionModel transaction) async {
    try {
      final preferences = await prefs;
      final transactions = await getTransactions();

      final index = transactions.indexWhere((t) => t.id == transaction.id);
      if (index != -1) {
        transactions[index] = transaction.copyWith(updatedAt: DateTime.now());

        final transactionsJson = transactions
            .map((t) => jsonEncode(t.toMap()))
            .toList();

        return await preferences.setStringList(
          'transactions',
          transactionsJson,
        );
      }
      return false;
    } catch (e) {
      print('Error updating transaction: $e');
      return false;
    }
  }

  Future<bool> deleteTransaction(int id) async {
    try {
      final preferences = await prefs;
      final transactions = await getTransactions();

      transactions.removeWhere((t) => t.id == id);

      final transactionsJson = transactions
          .map((t) => jsonEncode(t.toMap()))
          .toList();

      return await preferences.setStringList('transactions', transactionsJson);
    } catch (e) {
      print('Error deleting transaction: $e');
      return false;
    }
  }

  Future<double> getTotalBalance() async {
    try {
      final transactions = await getTransactions();
      double total = 0.0;
      for (final transaction in transactions) {
        total += transaction.isPositive
            ? transaction.amount
            : -transaction.amount;
      }
      return total;
    } catch (e) {
      print('Error calculating balance: $e');
      return 0.0;
    }
  }

  Future<void> clearAllData() async {
    try {
      final preferences = await prefs;
      await preferences.clear();
    } catch (e) {
      print('Error clearing data: $e');
    }
  }
}
