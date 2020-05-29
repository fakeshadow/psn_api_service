import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend_service/bloc/PSNBloc.dart';
import 'package:frontend_service/widget/MarkDownWidget.dart';

class PSNResponseWidget extends StatelessWidget {
  final int index;

  PSNResponseWidget({this.index});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder(
      bloc: BlocProvider.of<PSNBloc>(context),
      builder: (context, state) {
        if (state is PSNLoading) {
          return Container(
            height: 50,
            width: 50,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (state is PSNLoaded) {
          return MarkDownResponseWidget(index: this.index, psnData: state.psnData);
        }
        return Container();
      },
    );
  }
}