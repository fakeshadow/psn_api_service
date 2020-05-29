import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_service/api/PSNAPI.dart';
import 'package:frontend_service/api/Storage.dart';
import 'package:frontend_service/bloc/ErrorBloc.dart';
import 'package:frontend_service/bloc/PSNBloc.dart';
import 'package:frontend_service/page/HomePage.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

// remote psn api server ip
const String url = "https://api.blackheart.top";

class _MyAppState extends State<MyApp> {
  PSNBloc psnBloc;
  ErrorBloc errorBloc;
  Storage storage;

  @override
  void initState() {
    storage = Storage.init();
    errorBloc = new ErrorBloc();
    psnBloc = new PSNBloc(psnapi: PSNAPI(url: url), errorBloc: errorBloc, storage: storage);
    super.initState();
  }

  @override
  void dispose() {
    psnBloc.close();
    errorBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => psnBloc),
        BlocProvider(create: (context) => errorBloc),
      ],
      child: MaterialApp(
        title: 'PSN_API_SERVER_FRONT_END',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        routes: {
          '/': (context) => MyHomePage(),
        },
        initialRoute: '/',
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
