import 'package:flutter/material.dart';

/// BR-06 / TC-18: guests can browse and fill a cart, but must log in to
/// order. True = "Log in", false = "Not now". The cart is kept either way.
Future<bool> askGuestToLogIn(BuildContext context) async {
  final logIn = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Log in to order'),
      content: const Text(
        'Guests can browse, but you need an account to place an order. '
        'Your cart will be kept.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Log in'),
        ),
      ],
    ),
  );
  return logIn ?? false;
}
