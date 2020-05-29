import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

abstract class ErrorBlocEvent extends Equatable {
  const ErrorBlocEvent();

  @override
  List<Object> get props => [];
}

class ResetError extends ErrorBlocEvent {}

class GotError extends ErrorBlocEvent {
  final String error;

  const GotError({this.error});

  @override
  List<Object> get props => [error];
}

abstract class ErrorBlocState extends Equatable {
  const ErrorBlocState();

  @override
  List<Object> get props => [];
}

class ErrorUninitialized extends ErrorBlocState {}

class HaveError extends ErrorBlocState {
  final String error;

  const HaveError({this.error});

  @override
  List<Object> get props => [error];
}

class ErrorBloc extends Bloc<ErrorBlocEvent, ErrorBlocState> {
  @override
  ErrorBlocState get initialState => ErrorUninitialized();

  @override
  Stream<ErrorBlocState> mapEventToState(ErrorBlocEvent event) async* {
    if (event is GotError) {
      yield HaveError(error: event.error);
    }
    if (event is ResetError) {
      yield ErrorUninitialized();
    }
  }
}
