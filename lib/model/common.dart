class RemoteData<T> {
  final DateTime timestamp;
  final T data;

  RemoteData({required this.timestamp, required this.data});
}

enum SatelliteState { deployment, safe, communication, charge, acquisition, transition, none }

enum CameraAngle { narrow, normal, wide }
