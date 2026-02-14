import 'package:flutter_test/flutter_test.dart';
import 'package:keystone_network/keystone_network.dart';

void main() {
  group('ApiState', () {
    group('Factory Constructors', () {
      test('idle creates IdleState', () {
        const state = ApiState<String, dynamic>.idle();
        expect(state, isA<IdleState<String, dynamic>>());
        expect(state.isIdle, isTrue);
      });

      test('loading creates LoadingState', () {
        const state = ApiState<String, dynamic>.loading();
        expect(state, isA<LoadingState<String, dynamic>>());
        expect(state.isLoading, isTrue);
      });

      test('success creates SuccessState with data', () {
        const data = 'test data';
        const state = ApiState<String, dynamic>.success(data);
        expect(state, isA<SuccessState<String, dynamic>>());
        expect(state.isSuccess, isTrue);
        expect(state.data, equals(data));
      });

      test('failed creates FailedState with error', () {
        const error = FailureResponse<dynamic>(400, 'Bad Request');
        const state = ApiState<String, dynamic>.failed(error);
        expect(state, isA<FailedState<String, dynamic>>());
        expect(state.isFailed, isTrue);
        expect(state.error, equals(error));
      });

      test('networkError creates NetworkErrorState with error', () {
        const error = FailureResponse<dynamic>(-2, 'No Internet');
        const state = ApiState<String, dynamic>.networkError(error);
        expect(state, isA<NetworkErrorState<String, dynamic>>());
        expect(state.isNetworkError, isTrue);
        expect(state.error, equals(error));
      });
    });

    group('Data Getters', () {
      test('data returns value for SuccessState', () {
        const state = ApiState<String, dynamic>.success('test');
        expect(state.data, equals('test'));
        expect(state.dataOrNull, equals('test'));
        expect(state.hasData, isTrue);
      });

      test('data returns null for non-success states', () {
        expect(ApiState<String, dynamic>.idle().data, isNull);
        expect(ApiState<String, dynamic>.loading().data, isNull);
        expect(
          ApiState<String, dynamic>.failed(
            const FailureResponse(400, 'Error'),
          ).data,
          isNull,
        );
      });

      test('error returns value for FailedState', () {
        const error = FailureResponse<dynamic>(400, 'Bad Request');
        const state = ApiState<String, dynamic>.failed(error);
        expect(state.error, equals(error));
        expect(state.errorOrNull, equals(error));
        expect(state.hasError, isTrue);
      });

      test('error returns value for NetworkErrorState', () {
        const error = FailureResponse<dynamic>(-2, 'No Internet');
        const state = ApiState<String, dynamic>.networkError(error);
        expect(state.error, equals(error));
        expect(state.errorOrNull, equals(error));
        expect(state.hasError, isTrue);
      });

      test('error returns null for non-error states', () {
        expect(ApiState<String, dynamic>.idle().error, isNull);
        expect(ApiState<String, dynamic>.loading().error, isNull);
        expect(ApiState<String, dynamic>.success('test').error, isNull);
      });
    });

    group('Pattern Matching - when', () {
      test('matches idle state', () {
        const state = ApiState<String, dynamic>.idle();
        final result = state.when(
          idle: () => 'idle',
          loading: () => 'loading',
          success: (data) => 'success: $data',
          failed: (error) => 'failed: ${error.message}',
          networkError: (error) => 'network: ${error.message}',
        );
        expect(result, equals('idle'));
      });

      test('matches loading state', () {
        const state = ApiState<String, dynamic>.loading();
        final result = state.when(
          idle: () => 'idle',
          loading: () => 'loading',
          success: (data) => 'success: $data',
          failed: (error) => 'failed: ${error.message}',
          networkError: (error) => 'network: ${error.message}',
        );
        expect(result, equals('loading'));
      });

      test('matches success state with data', () {
        const state = ApiState<String, dynamic>.success('test data');
        final result = state.when(
          idle: () => 'idle',
          loading: () => 'loading',
          success: (data) => 'success: $data',
          failed: (error) => 'failed: ${error.message}',
          networkError: (error) => 'network: ${error.message}',
        );
        expect(result, equals('success: test data'));
      });

      test('matches failed state with error', () {
        const state = ApiState<String, dynamic>.failed(
          FailureResponse(400, 'Bad Request'),
        );
        final result = state.when(
          idle: () => 'idle',
          loading: () => 'loading',
          success: (data) => 'success: $data',
          failed: (error) => 'failed: ${error.message}',
          networkError: (error) => 'network: ${error.message}',
        );
        expect(result, equals('failed: Bad Request'));
      });

      test('matches network error state', () {
        const state = ApiState<String, dynamic>.networkError(
          FailureResponse(-2, 'No Internet'),
        );
        final result = state.when(
          idle: () => 'idle',
          loading: () => 'loading',
          success: (data) => 'success: $data',
          failed: (error) => 'failed: ${error.message}',
          networkError: (error) => 'network: ${error.message}',
        );
        expect(result, equals('network: No Internet'));
      });
    });

    group('Pattern Matching - maybeWhen', () {
      test('uses specific handler when provided', () {
        const state = ApiState<String, dynamic>.success('test');
        final result = state.maybeWhen(
          success: (data) => 'got: $data',
          orElse: () => 'other',
        );
        expect(result, equals('got: test'));
      });

      test('uses orElse when handler not provided', () {
        const state = ApiState<String, dynamic>.loading();
        final result = state.maybeWhen(
          success: (data) => 'got: $data',
          orElse: () => 'other',
        );
        expect(result, equals('other'));
      });

      test('orElse is required', () {
        const state = ApiState<String, dynamic>.idle();
        final result = state.maybeWhen(
          loading: () => 'loading',
          orElse: () => 'default',
        );
        expect(result, equals('default'));
      });
    });

    group('Map Transformation', () {
      test('transforms success data', () {
        const state = ApiState<int, dynamic>.success(42);
        final mapped = state.map<String>((data) => 'Number: $data');

        expect(mapped, isA<SuccessState<String, dynamic>>());
        expect(mapped.data, equals('Number: 42'));
      });

      test('preserves idle state during map', () {
        const state = ApiState<int, dynamic>.idle();
        final mapped = state.map<String>((data) => 'Number: $data');

        expect(mapped, isA<IdleState<String, dynamic>>());
        expect(mapped.data, isNull);
      });

      test('preserves loading state during map', () {
        const state = ApiState<int, dynamic>.loading();
        final mapped = state.map<String>((data) => 'Number: $data');

        expect(mapped, isA<LoadingState<String, dynamic>>());
        expect(mapped.data, isNull);
      });

      test('preserves error during map', () {
        const error = FailureResponse<dynamic>(500, 'Server Error');
        const state = ApiState<int, dynamic>.failed(error);
        final mapped = state.map<String>((data) => 'Number: $data');

        expect(mapped, isA<FailedState<String, dynamic>>());
        expect(mapped.error, equals(error));
      });

      test('preserves network error during map', () {
        const error = FailureResponse<dynamic>(-2, 'No Internet');
        const state = ApiState<int, dynamic>.networkError(error);
        final mapped = state.map<String>((data) => 'Number: $data');

        expect(mapped, isA<NetworkErrorState<String, dynamic>>());
        expect(mapped.error, equals(error));
      });
    });

    group('Convenience Extensions', () {
      test('isIdle works correctly', () {
        expect(ApiState<String, dynamic>.idle().isIdle, isTrue);
        expect(ApiState<String, dynamic>.loading().isIdle, isFalse);
        expect(ApiState<String, dynamic>.success('test').isIdle, isFalse);
      });

      test('isLoading works correctly', () {
        expect(ApiState<String, dynamic>.loading().isLoading, isTrue);
        expect(ApiState<String, dynamic>.idle().isLoading, isFalse);
        expect(ApiState<String, dynamic>.success('test').isLoading, isFalse);
      });

      test('isSuccess works correctly', () {
        expect(ApiState<String, dynamic>.success('test').isSuccess, isTrue);
        expect(ApiState<String, dynamic>.idle().isSuccess, isFalse);
        expect(ApiState<String, dynamic>.loading().isSuccess, isFalse);
      });

      test('isFailed works correctly', () {
        const error = FailureResponse<dynamic>(400, 'Error');
        expect(ApiState<String, dynamic>.failed(error).isFailed, isTrue);
        expect(ApiState<String, dynamic>.success('test').isFailed, isFalse);
      });

      test('isNetworkError works correctly', () {
        const error = FailureResponse<dynamic>(-2, 'No Internet');
        expect(
          ApiState<String, dynamic>.networkError(error).isNetworkError,
          isTrue,
        );
        expect(
          ApiState<String, dynamic>.success('test').isNetworkError,
          isFalse,
        );
      });

      test('isError combines failed and network error', () {
        const failedError = FailureResponse<dynamic>(400, 'Error');
        const networkError = FailureResponse<dynamic>(-2, 'No Internet');

        expect(ApiState<String, dynamic>.failed(failedError).isError, isTrue);
        expect(
          ApiState<String, dynamic>.networkError(networkError).isError,
          isTrue,
        );
        expect(ApiState<String, dynamic>.success('test').isError, isFalse);
        expect(ApiState<String, dynamic>.idle().isError, isFalse);
      });
    });

    group('Equality', () {
      test('IdleState equality', () {
        const state1 = IdleState<String, dynamic>();
        const state2 = IdleState<String, dynamic>();
        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('LoadingState equality', () {
        const state1 = LoadingState<String, dynamic>();
        const state2 = LoadingState<String, dynamic>();
        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('SuccessState equality with same data', () {
        const state1 = SuccessState<String, dynamic>('test');
        const state2 = SuccessState<String, dynamic>('test');
        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('SuccessState inequality with different data', () {
        const state1 = SuccessState<String, dynamic>('test1');
        const state2 = SuccessState<String, dynamic>('test2');
        expect(state1, isNot(equals(state2)));
      });

      test('FailedState equality with same error', () {
        const error = FailureResponse<dynamic>(400, 'Error');
        const state1 = FailedState<String, dynamic>(error);
        const state2 = FailedState<String, dynamic>(error);
        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('NetworkErrorState equality', () {
        const error = FailureResponse<dynamic>(-2, 'No Internet');
        const state1 = NetworkErrorState<String, dynamic>(error);
        const state2 = NetworkErrorState<String, dynamic>(error);
        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('Different state types are not equal', () {
        expect(
          ApiState<String, dynamic>.idle(),
          isNot(equals(ApiState<String, dynamic>.loading())),
        );
        expect(
          ApiState<String, dynamic>.success('test'),
          isNot(equals(ApiState<String, dynamic>.idle())),
        );
      });
    });

    group('toString', () {
      test('IdleState toString', () {
        const state = IdleState<String, dynamic>();
        expect(state.toString(), equals('ApiState<String, dynamic>.idle()'));
      });

      test('LoadingState toString', () {
        const state = LoadingState<String, dynamic>();
        expect(state.toString(), equals('ApiState<String, dynamic>.loading()'));
      });

      test('SuccessState toString', () {
        const state = SuccessState<String, dynamic>('test data');
        expect(
          state.toString(),
          equals('ApiState<String, dynamic>.success(test data)'),
        );
      });

      test('FailedState toString', () {
        const state = FailedState<String, dynamic>(
          FailureResponse(400, 'Error'),
        );
        expect(
          state.toString(),
          contains('ApiState<String, dynamic>.failed'),
        );
      });

      test('NetworkErrorState toString', () {
        const state = NetworkErrorState<String, dynamic>(
          FailureResponse(-2, 'No Internet'),
        );
        expect(
          state.toString(),
          contains('ApiState<String, dynamic>.networkError'),
        );
      });
    });

    group('Type Safety', () {
      test('Success state preserves generic type', () {
        const state = ApiState<int, dynamic>.success(42);
        expect(state.data, isA<int>());
        expect(state.data, equals(42));
      });

      test('Error state preserves custom error type', () {
        final customError = {'field': 'email', 'message': 'Invalid'};
        const error = FailureResponse<Map<String, dynamic>>(
          400,
          'Validation Error',
          errorData: {'field': 'email', 'message': 'Invalid'},
        );
        const state = ApiState<String, Map<String, dynamic>>.failed(error);

        expect(state.error?.errorData, isA<Map<String, dynamic>>());
        expect(state.error?.errorData?['field'], equals('email'));
      });
    });
  });
}