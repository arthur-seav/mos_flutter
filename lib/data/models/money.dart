import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// An amount in US dollars, stored as whole cents.
///
/// Prices are NUMERIC(10,2) in the database. Keeping cents as an [int]
/// avoids floating-point errors such as 0.1 + 0.2 = 0.30000000000000004
/// when the cart adds prices up (BR-03).
@immutable
class Money implements Comparable<Money> {
  const Money.cents(this.cents);

  /// From a dollar amount as written in the SA, e.g. `Money.dollars(3.5)`.
  Money.dollars(num dollars) : cents = (dollars * 100).round();

  static const zero = Money.cents(0);

  final int cents;

  static final _format = NumberFormat.simpleCurrency(name: 'USD');

  Money operator +(Money other) => Money.cents(cents + other.cents);
  Money operator *(int quantity) => Money.cents(cents * quantity);

  /// "$3.50"
  String format() => _format.format(cents / 100);

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  @override
  bool operator ==(Object other) => other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  @override
  String toString() => format();
}
