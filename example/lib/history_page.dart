
import 'package:cashu_dart/api/v1/cashu_financial_api.dart';
import 'package:flutter/material.dart';
import 'package:cashu_dart/model/history_entry.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage(this.initialData, {super.key});
  final List<IHistoryEntry> initialData;

  @override
  State<StatefulWidget> createState() => HistoryPageState();
}

class HistoryPageState extends State<HistoryPage> {
  final ScrollController _scrollController = ScrollController();
  List<IHistoryEntry> _data = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && !_isLoading) {
      _loadMoreData();
    }
  }

  Future _loadMoreData() async {

    final lastDataId = _data.lastOrNull?.id ?? '';

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(Duration(seconds: 2));
    final newData = await CashuFinancialAPI.getHistoryList(lastHistoryId: lastDataId);

    setState(() {
      _isLoading = false;
      _data.addAll(newData);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: _data.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < _data.length) {
            final item = _data[index];
            return ListTile(
              title: Text(item.type.text),
              subtitle: Text(item.timestamp.toString()),
              trailing: Text(item.amount.toString()),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

extension IHistoryTypeUIEx on IHistoryType {
  String get text {
    switch(this) {
      case IHistoryType.eCash: return 'Ecash Payment';
      case IHistoryType.lnInvoice: return 'Lightning Payment';
      case IHistoryType.multiMintSwap: return 'Swap';
      default: return 'Unknown';
    }
  }
}