import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_service/bloc/PSNBloc.dart';

class PSNRequestTextFieldWidget extends StatefulWidget {
  final int index;

  PSNRequestTextFieldWidget({this.index});

  @override
  _PSNRequestTextFieldWidgetState createState() =>
      _PSNRequestTextFieldWidgetState();
}

class _PSNRequestTextFieldWidgetState extends State<PSNRequestTextFieldWidget> {
  TextEditingController _controllerPSNId;
  TextEditingController _controllerOffset;
  TextEditingController _controllerNPId;

  TextEditingController _controllerLang;
  TextEditingController _controllerRegion;
  TextEditingController _controllerAge;
  TextEditingController _controllerName;

  PSNBloc _bloc;

  bool validPSNId;
  bool validOffset;
  bool validNPId;
  bool validLang;
  bool validRegion;
  bool validAge;

  @override
  void initState() {
    _bloc = BlocProvider.of<PSNBloc>(this.context);

    _controllerPSNId = new TextEditingController();
    _controllerOffset = new TextEditingController();
    _controllerNPId = new TextEditingController();

    _controllerLang = new TextEditingController();
    _controllerRegion = new TextEditingController();
    _controllerAge = new TextEditingController();
    _controllerName = new TextEditingController();

    validPSNId = false;
    validOffset = false;
    validNPId = false;

    validLang = false;
    validRegion = false;
    validAge = false;

    _controllerPSNId.addListener(() {
      if (_controllerPSNId.text.length > 3) {
        setState(() {
          validPSNId = true;
        });
      } else {
        setState(() {
          validPSNId = false;
        });
      }
    });

    _controllerOffset.addListener(() {
      if (int.tryParse(_controllerOffset.text) != null) {
        setState(() {
          validOffset = true;
        });
      } else {
        setState(() {
          validOffset = false;
        });
      }
    });

    _controllerNPId.addListener(() {
      final text = _controllerNPId.text;
      if (text.startsWith("NPWR") && text.length >= 12) {
        setState(() {
          validNPId = true;
        });
      } else {
        setState(() {
          validNPId = false;
        });
      }
    });

    _controllerAge.addListener(() {
      if (int.tryParse(_controllerAge.text) != null) {
        setState(() {
          validAge = true;
        });
      } else {
        setState(() {
          validAge = false;
        });
      }
    });

    _controllerLang.addListener(() {
      final text = _controllerLang.text;
      if (text.length < 2) {
        setState(() {
          validLang = false;
        });
      } else {
        setState(() {
          validLang = true;
        });
      }
    });

    _controllerRegion.addListener(() {
      final text = _controllerRegion.text;
      if (text.length < 2) {
        setState(() {
          validRegion = false;
        });
      } else {
        setState(() {
          validRegion = true;
        });
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _controllerPSNId.dispose();
    _controllerOffset.dispose();
    _controllerNPId.dispose();

    _controllerLang.dispose();
    _controllerRegion.dispose();
    _controllerAge.dispose();
    _controllerName.dispose();
    super.dispose();
  }

  bool _validateInput() {
    final int index = widget.index;

    if (index == 0 && validPSNId) {
      return true;
    }

    if (index == 1 && validPSNId && validOffset) {
      return true;
    }

    if (index == 2 && validPSNId && validNPId) {
      return true;
    }

    if (index == 4 && validRegion && validLang && validAge) {
      return true;
    }

    return false;
  }

  void handleRequest() {
    _bloc.add(Loading());
    switch (widget.index) {
      case 0:
        {
          final onlineId = _controllerPSNId.text;
          _bloc.add(GetProfile(onlineId: onlineId));
          break;
        }
      case 1:
        {
          final onlineId = _controllerPSNId.text;
          final offset = _controllerOffset.text;
          _bloc.add(GetTrophyTitles(onlineId: onlineId, offset: offset));
          break;
        }
      case 2:
        {
          final onlineId = _controllerPSNId.text;
          final npId = _controllerNPId.text;
          _bloc.add(GetTrophySet(onlineId: onlineId, npId: npId));
          break;
        }
      case 3:
        {
          break;
        }
      case 4:
        {
          final region = _controllerRegion.text;
          final lang = _controllerLang.text;
          final age = _controllerAge.text;
          final name = _controllerName.text;
          _bloc.add(
              GetStoreItem(lang: lang, region: region, age: age, name: name));
          break;
        }
      case 5:
        {
          break;
        }
    }
    _controllerPSNId.text = "";
    _controllerNPId.text = "";
    _controllerOffset.text = "";
    _controllerRegion.text = "";
    _controllerLang.text = "";
    _controllerAge.text = "";
    _controllerName.text = "";
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder(
        bloc: _bloc,
        builder: (context, state) {
          if (state is PSNUninitialized) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                (widget.index != 3 && widget.index != 4 && widget.index != 5)
                    ? Container(
                        width: 170,
                        child: _textField(_controllerPSNId, 'PSN ID'),
                      )
                    : Container(),
                widget.index == 1
                    ? Container(
                        width: 80,
                        child: _textField(_controllerOffset, 'Offset'),
                      )
                    : Container(),
                widget.index == 2
                    ? Container(
                        width: 170,
                        child: _textField(_controllerNPId, 'NP Community ID'),
                      )
                    : Container(),
                ..._storeSearchField(),
                Container(
                  height: 39,
                  child: FlatButton(
                      disabledColor: Colors.black12,
                      color: Colors.blue,
                      textColor: Colors.white,
                      child: Text("Confirm"),
                      onPressed: _validateInput() == true
                          ? () => handleRequest()
                          : null),
                )
              ],
            );
          } else {
            return Container();
          }
        });
  }

  List<Widget> _storeSearchField() {
     if (widget.index == 4) {
       return [
         Container(
           width: 200,
           child: _textField(_controllerName, 'Game Name'),
         ),
         Container(
           width: 80,
           child: _textField(_controllerLang, 'Lang'),
         ),
         Container(
           width: 80,
           child: _textField(_controllerRegion, 'Region'),
         ),Container(
           width: 50,
           child: _textField(_controllerAge, 'Age'),
         )
       ];
     } else {
       return [
         Container()
       ];
     }
  }

  Widget _textField(TextEditingController controller, String hintText) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.all(9.99999),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black12, width: 1.0),
        ),
        hintText: hintText,
      ),
    );
  }
}
