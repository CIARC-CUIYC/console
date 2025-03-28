# ciarc_console

Console for CIARC

## Code structure
The code is structured in three core packages:
* `model` Contains the internal datamodels, this includes the abstracted model of the melvin api aswell the model of the custom api used for communication with melvin-ob
* `service` Contains the two communication services.
  * The service `groud_station_client` handles communication with the melvin rest api an is used for fetching objectives, achievement.
  * The service `melvin` handles communication with melvin-ob, it provides observability functionality like retrieving a live stream of the imaging process and the current task list aswell as control functionality for marking the zon of secret objectives
* `ui` Holds user interface related components

## Communication with Melvin-OB
The following shows how the communication between the console and melvin-ob is implemented.
The main design goals were to create a 1. easy-to-use solution that 2. relays on minimal data transfer.
For accomplishing these goals we implemented communication using two different interfaces / data path.

The first data path is used for pulling information about the challenge (objectives, achievements, available communications slots and announcements)
and for booking communications slots. The information exchange is conducted directly via the Melvin REST API tunneled over Wireguard

The second data path is used for interacting directly with melvin-ob and is used for pulling internal state information, the world image and
controlling the scheduling and submission of objectives. It's based on Protobuf Serialisation and direct TCP socket. This rather unusual design choice
was made for a better data rate utilisation in comparison then a REST / Websockets on HTTP approach.

![architecture](architecture.png)

To provide an efficient live stream of the imaging process this second data path is used.
After initial connection of the console melvin-ob sends a thumbnail of the complete world map.
Melvin also keeps sending changed chunks after new images were taken and patched into the internal world image. 
If the console reconnects after a communication pause it requests a differential thumbnail that contains all changed parts
since the last connection.



### Build
The following assumes flutter / dart sdk and protoc installed 
```bash
flutter pub get
cd lib
protoc model/melvin_messages.proto --dart_out=.
cd ..
dart pub run build_runner build
flutter run
```