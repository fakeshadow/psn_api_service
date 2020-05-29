import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend_service/api/PSNAPI.dart';
import 'package:frontend_service/api/Storage.dart';
import 'package:frontend_service/bloc/ErrorBloc.dart';

abstract class PSNBlocEvent extends Equatable {
  const PSNBlocEvent();

  @override
  List<Object> get props => [];
}

class Reset extends PSNBlocEvent {}

class Loading extends PSNBlocEvent {}

class GetProfile extends PSNBlocEvent {
  final String onlineId;

  const GetProfile({this.onlineId});

  @override
  List<Object> get props => [];
}

class GetTrophyTitles extends PSNBlocEvent {
  final String onlineId, offset;

  const GetTrophyTitles({this.onlineId, this.offset});

  @override
  List<Object> get props => [onlineId, offset];
}

class GetTrophySet extends PSNBlocEvent {
  final String onlineId, npId;

  const GetTrophySet({this.onlineId, this.npId});

  @override
  List<Object> get props => [onlineId, npId];
}

class GetStoreItem extends PSNBlocEvent {
  final String region, lang, age, name;

  const GetStoreItem({this.region, this.lang, this.age, this.name});

  @override
  List<Object> get props => [region, lang, age, name];
}

abstract class PSNBlocState extends Equatable {
  const PSNBlocState();

  @override
  List<Object> get props => [];
}

class PSNUninitialized extends PSNBlocState {}

class PSNLoading extends PSNBlocState {}

class PSNLoaded extends PSNBlocState {
  final Map<String, dynamic> psnData;

  const PSNLoaded({this.psnData});

  @override
  List<Object> get props => [psnData];
}

class PSNError extends PSNBlocState {
  final String psnError;

  const PSNError({this.psnError});

  @override
  List<Object> get props => [psnError];
}

class PSNBloc extends Bloc<PSNBlocEvent, PSNBlocState> {
  final PSNAPI psnapi;
  final ErrorBloc errorBloc;
  final Storage storage;

  PSNBloc({this.psnapi, this.errorBloc, this.storage});

  @override
  PSNBlocState get initialState => PSNUninitialized();

  void _handleError(String error) async {
    this.errorBloc.add(GotError(error: error));
    this.errorBloc.add(ResetError());
  }

  Future<void> _canMakeRequest() async {
    final String instant = await this.storage.getInstant();
    final DateTime dateTime =
        instant == null ? null : DateTime.tryParse(instant);
    if (dateTime != null) {
      final differ = (60000 - (DateTime.now().millisecondsSinceEpoch - dateTime.millisecondsSinceEpoch)) / 1000;

      if (differ > 0) {
        throw ("Rate limit hit please wait another $differ seconds");
      }
    }

    await this.storage.setInstant();
  }

  @override
  Stream<PSNBlocState> mapEventToState(PSNBlocEvent event) async* {
    if (event is Reset) {
      yield PSNUninitialized();
    }

    if (event is Loading) {
      yield PSNLoading();
    }

    if (event is GetProfile) {
      try {
        await _canMakeRequest();
        final psnData = await this.psnapi.getProfile(event.onlineId);
        yield PSNLoaded(psnData: psnData);
      } catch (e) {
        _handleError(e);
        yield PSNUninitialized();
      }
    }

    if (event is GetTrophyTitles) {
      try {
        await _canMakeRequest();
        final psnData =
            await this.psnapi.getTitles(event.onlineId, event.offset);

        yield PSNLoaded(psnData: psnData);
      } catch (e) {
        _handleError(e);
        yield PSNUninitialized();
      }
    }

    if (event is GetTrophySet) {
      try {
        await _canMakeRequest();
        final psnData = await this.psnapi.getSet(event.onlineId, event.npId);

        yield PSNLoaded(psnData: psnData);
      } catch (e) {
        _handleError(e);
        yield PSNUninitialized();
      }
    }

    if (event is GetStoreItem) {
      try {
        await _canMakeRequest();
        final psnData = await this
            .psnapi
            .getStore(event.lang, event.region, event.age, event.name);

        yield PSNLoaded(psnData: psnData);
      } catch (e) {
        _handleError(e);
        yield PSNUninitialized();
      }
    }
  }
}
