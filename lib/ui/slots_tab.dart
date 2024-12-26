import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../model/slot.dart';
import '../service/ground_station_client.dart';
import 'time_ago.dart';

class SlotsTab extends StatelessWidget {
  SlotsTab({super.key});

  final GroundStationClient _groundStationClient = getIt.get();
  static final DateFormat _dateFormat = DateFormat.MEd("de_DE").add_Hm();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _groundStationClient.slots,
    builder: (context, slots, widget_) {
      if (slots == null) {
        return Center(child: CircularProgressIndicator());
      } else if (slots.data.isEmpty) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("No slots available"),
            TimeAgo(timestamp: slots.timestamp, builder: (context, timeText) => Text("Last updated: $timeText")),
          ],
        );
      }

      return ListView.separated(
        itemBuilder: (context, index) {
          if (index == slots.data.length) {
            return Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(vertical: 10),
              child: TimeAgo(
                timestamp: slots.timestamp,
                builder: (context, timeText) => Text("Last updated: $timeText"),
              ),
            );
          }
          final slot = slots.data[index];
          return ListTile(
            trailing: OutlinedButton(
              onPressed: () {
                _groundStationClient.bookSlot(slot.id, unBook: slot.booked).catchError((e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not book / unbook slot")));
                });
              },
              child: Text(slot.booked ? "Unbook" : "Book"),
            ),
            title: Text(_formatSlotTime(slot), style: TextStyle(fontWeight: slot.booked ? FontWeight.bold : null)),
          );
        },
        separatorBuilder: (context, index) => Divider(indent: 5, height: 2, thickness: 1),
        itemCount: slots.data.length + 1,
      );
    },
  );

  String _formatSlotTime(Slot slot) {
    return "${_dateFormat.format(slot.start)} - ${_dateFormat.format(slot.end)}";
  }
}
