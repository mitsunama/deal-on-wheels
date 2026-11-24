import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key, });

  @override

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(Icons.directions_car_filled, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text('Deal on Wheels',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Version 1.0.0', textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              const Text(
                'Deal on Wheels is a marketplace where people list vehicles for sale '
                'and buyers start a deal directly with the seller.',
              ),
              const SizedBox(height: 24),
              Text('How a deal works',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const _Step(n: 1, text: 'A buyer opens a vehicle and starts a deal. '
                  'The vehicle is reserved (pending).'),
              const _Step(n: 2, text: 'The seller confirms the sale in the Transactions tab. '
                  'The vehicle is marked as sold.'),
              const _Step(n: 3, text: 'Either side can cancel a pending deal, which puts '
                  'the vehicle back on the market.'),
              const SizedBox(height: 24),
              Text('Server: ${api.baseUrl}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 12, child: Text('$n', style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}