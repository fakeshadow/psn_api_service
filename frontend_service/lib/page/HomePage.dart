// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:frontend_service/bloc/ErrorBloc.dart';
import 'package:frontend_service/bloc/PSNBloc.dart';
import 'package:frontend_service/widget/MarkDownWidget.dart';
import 'package:frontend_service/widget/PSNRequestTextFieldWidget.dart';
import 'package:frontend_service/widget/PSNResponseWidget.dart';

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const _buttonList = [
    "GetProfile",
    "GetTrophyTitles",
    "GetTrophySet",
    "SendMessage",
    "SearchStore",
    "Authentication",
  ];

  int index;

  ScrollController _controllerReq;

  @override
  void initState() {
    index = 0;
    _controllerReq = new ScrollController();
    super.initState();
  }

  setIndex(int index) {
    BlocProvider.of<PSNBloc>(context).add(Reset());
    setState(() {
      this.index = index;
    });
  }

  @override
  void dispose() {
    _controllerReq.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          Container(height: 40),
          Text("PSN API Demo", style: TextStyle(fontSize: 22)),
          Container(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _buttonList
                .asMap()
                .entries
                .map((entry) => _indexedButton(entry.key, entry.value))
                .toList(),
          ),
          Container(height: 10),
          MarkDownReqWidget(index: this.index),
          Container(height: 30),
          (this.index != 5 && this.index != 3)
              ? PSNRequestTextFieldWidget(index: this.index)
              : Container(),
          PSNResponseWidget(index: this.index),
        ]),
      ),
      bottomNavigationBar: BlocListener<ErrorBloc, ErrorBlocState>(
        listener: (context, state) {
          if (state is HaveError) {
            Scaffold.of(context).showSnackBar(SnackBar(
                content: Text(state.error, style: TextStyle(fontSize: 22))));
          }
        },
        child: Container(
          color: Colors.blue[200],
          height: 40,
          child: Row(
            children: [
              Spacer(),
              FlatButton.icon(
                icon: Icon(FlutterIcons.github_ant),
                label: Text("Source Code"),
                onPressed: () => html.window.location.href =
                    "https://github.com/fakeshadow/psn_api_server",
              ),
              Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _indexedButton(int targetIndex, String buttonText) {
    return FlatButton(
      color: this.index == targetIndex ? Colors.blue : Colors.transparent,
      textColor: this.index == targetIndex ? Colors.white : Colors.black,
      child: Text(buttonText),
      onPressed: () {
        setIndex(targetIndex);
      },
    );
  }
}
