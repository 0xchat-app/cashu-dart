
import 'package:cashu_dart/business/mint/mint_helper.dart';
import 'package:cashu_dart/cashu_dart.dart';
import 'package:cashu_dart_example/history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cashu_dart/business/wallet/cashu_manager.dart';
import 'package:cashu_dart/model/mint_model.dart';

import 'main.reflectable.dart';
import 'dart:async';


void main() {
  initializeReflectable();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  Future setupComplete = CashuManager.shared.setup('test', dbVersion: 1);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Cashu Plugin example app'),
        ),
        body: FutureBuilder(
          future: setupComplete,
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return const ExamplePage();
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          }
        )
      ),
    );
  }
}

class ExamplePage extends StatefulWidget {

  const ExamplePage({super.key});

  @override
  State<StatefulWidget> createState() => ExamplePageState();
}

class ExamplePageState extends State<ExamplePage> {

  IMint? selectedMint;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        buildTotalBalance(),
        buildMintList(),
        if (selectedMint != null)
          buildMintInfo(),
        buildOptionView(),
      ],
    );
  }

  Widget buildTotalBalance() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 5,),
        Text('total balance: ${CashuFinancialAPI.totalBalance()}'),
        const SizedBox(height: 5,),
      ],
    );
  }

  Widget buildMintList() {
    final mints = [...CashuMintAPI.mintList()];
    return Container(
      color: Colors.orange,
      height: 140,
      child: Column(
        children: [
          const SizedBox(height: 20,),
          const Text('Mint list(click for selected)', style: TextStyle(fontWeight: FontWeight.bold),),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              scrollDirection: Axis.horizontal,
              itemCount: mints.length,
              itemBuilder: (BuildContext context, int index) {
                final mint = mints.first;
                return ElevatedButton(
                  onPressed: () {
                    setState(() {
                      if (selectedMint == mint) {
                        selectedMint = null;
                      } else {
                        selectedMint = mint;
                        MintHelper.updateMintInfoFromRemote(mint);
                      }
                    });
                  },
                  child: Row(
                    children: [
                      Radio(value: mint, groupValue: selectedMint, onChanged: null),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(mint.mintURL),
                          Text('local name: ${mint.name}'),
                          Text('balance: ${mint.balance} sat'),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMintInfo() {
    final mintInfo = selectedMint?.info;
    return Container(
      color: Colors.greenAccent,
      width: double.infinity,
      child: Column(
        children: [
          const SizedBox(height: 20,),
          const Text('Mint info', style: TextStyle(fontWeight: FontWeight.bold),),
          if (mintInfo == null)
            const CircularProgressIndicator()
          else
            ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(20),
              children: [
                Text('mintURL: ${mintInfo.mintURL}'),
                Text('name: ${mintInfo.name}'),
                Text('pubkey: ${mintInfo.pubkey}'),
                Text('version: ${mintInfo.version}'),
                Text('description: ${mintInfo.description}'),
                Text('contact: ${mintInfo.contact}'),
                Text('nuts: ${mintInfo.nuts}'),
              ],
            )
        ],
      ),
    );
  }

  Widget buildOptionView() {
    return Container(
      color: Colors.amber,
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20,),
          const Text('Action', style: TextStyle(fontWeight: FontWeight.bold),),
          buildOptionSectionHeader('Mint'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              runSpacing: 10,
              spacing: 10,
              direction: Axis.horizontal,
              children: [
                buildOptionItem('Add mint', addMint),
                buildOptionItem('Edit name', editMintName),
              ],
            ),
          ),
          buildOptionSectionHeader('Financial'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              runSpacing: 10,
              spacing: 10,
              direction: Axis.horizontal,
              children: [
                buildOptionItem('History', getHistoryList),
                buildOptionItem('Check proofs', checkProofsAvailable),
              ],
            ),
          ),
          buildOptionSectionHeader('Transaction'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 10,
              direction: Axis.horizontal,
              children: [
                buildOptionItem('Send Ecash', sendEcash),
                buildOptionItem('Redeem Ecash', redeemEcash),
                buildOptionItem('Pay Lightning invoice', payLightningInvoice),
                buildOptionItem('Create Lightning invoice', createLightningInvoice),
              ],
            ),
          ),
          const SizedBox(height: 20,),
        ],
      ),
    );
  }

  Widget buildOptionSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        child: Text(title),
      ),
    );
  }


  Widget buildOptionItem(String title, VoidCallback action) {
    return ElevatedButton(
      onPressed: action,
      child: Text(title),
    );
  }

  Future<String?> showInputDialog(String hint) async {
    final textFieldController = TextEditingController();
    String? result;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: TextField(
            controller: textFieldController,
            decoration: InputDecoration(hintText: hint),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('done'),
              onPressed: () {
                result = textFieldController.text;
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
    return result;
  }

  Future<(String input1, String input2)> showDoubleInputDialog(
    String hint1,
    String hint2,
  ) async {
    final textFieldController1 = TextEditingController();
    final textFieldController2 = TextEditingController();
    (String input1, String input2) results = ('', '');

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min, // 防止AlertDialog变得过大
            children: <Widget>[
              TextField(
                controller: textFieldController1,
                decoration: InputDecoration(hintText: hint1),
              ),
              TextField(
                controller: textFieldController2,
                decoration: InputDecoration(hintText: hint2),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('done'),
              onPressed: () {
                results = (textFieldController1.text, textFieldController2.text);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    return results;
  }

  showMessage(String message, bool isError) {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.red : Colors.black54,
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  updateUI() {
    setState(() { });
  }
}

extension ExamplePageStateActionEx on ExamplePageState {

  // Mint
  addMint() async {
    final mint = await showInputDialog('mint url');
    if (mint != null && mint.isNotEmpty) {
      final newMint = await CashuMintAPI.addMint(mint);
      if (newMint == null) {
        showMessage('Add mint fail', false);
      }
      updateUI();
    }
  }

  editMintName() async {
    final mint = selectedMint;
    if (mint == null) return null;
    final name = await showInputDialog('mint name');
    if (name != null && name.isNotEmpty) {
      CashuMintAPI.editMintName(mint, name);
      updateUI();
    }
  }

  // Financial
  getHistoryList() async {
    final history = await CashuFinancialAPI.getHistoryList();
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HistoryPage(history)),
      );
    }
  }

  checkProofsAvailable() async {
    final mint = selectedMint;
    if (mint == null) return null;
    CashuFinancialAPI.checkProofsAvailable(mint);
  }

  // transaction
  sendEcash() async {
    final mint = selectedMint;
    if (mint == null) return null;
    final input = await showInputDialog('amount');
    final amount = int.tryParse(input ?? '') ?? 0;
    if (amount == 0) return null;
    final result = await CashuTransactionAPI.sendEcash(mint: mint, amount: amount);
    if (result == null) {
      showMessage('Send Ecash failed', true);
    } else {
      showMessage('token: $result', false);
    }
  }

  redeemEcash() async {
    final mint = selectedMint;
    if (mint == null) return null;
    final input = await showInputDialog('token');
    if (input == null || input.isEmpty) return ;
    final result = await CashuTransactionAPI.redeemEcash(input);
    if (result == null) {
      showMessage('Redeem failed', true);
    } else {
      showMessage('memo: ${result.$1}\namount: ${result.$2}', false);
    }
  }

  payLightningInvoice() async {
    final mint = selectedMint;
    if (mint == null) return null;
    final input = await showInputDialog('invoice pr');
    if (input == null || input.isEmpty) return ;
    final success = await CashuTransactionAPI.payingLightningInvoice(
      mint: mint,
      pr: input,
    );
    if (!success) {
      showMessage('Pay failed', true);
    } else {
      showMessage('Pay success', false);
    }
  }

  createLightningInvoice() async {
    final mint = selectedMint;
    if (mint == null) return null;
    final input = await showInputDialog('amount');
    final amount = int.tryParse(input ?? '') ?? 0;
    if (amount == 0) return null;
    final invoice = await CashuTransactionAPI.createLightningInvoice(
      mint: mint,
      amount: amount,
      onSuccess: () {
        updateUI();
      },
    );
    if (invoice == null) {
      showMessage('Create failed', true);
    } else {
      showMessage('quote: ${invoice.quote}\nrequest: ${invoice.request}', false);
    }
  }
}
