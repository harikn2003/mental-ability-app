// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SessionRecordAdapter extends TypeAdapter<SessionRecord> {
  @override
  final int typeId = 0;

  @override
  SessionRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionRecord(
      date: fields[0] as DateTime,
      score: fields[1] as int,
      totalQuestions: fields[2] as int,
      skipped: fields[3] as int,
      mode: fields[4] as String,
      categoryCorrect: (fields[5] as Map).cast<String, int>(),
      categoryTotal: (fields[6] as Map).cast<String, int>(),
      avgTimeSeconds: fields[7] as int,
      attemptSnapshots: fields[8] == null
          ? []
          : (fields[8] as List).cast<Map<dynamic, dynamic>>(),
    );
  }

  @override
  void write(BinaryWriter writer, SessionRecord obj) {
    writer.writeByte(9);
    writer.writeByte(0);
    writer.write(obj.date);
    writer.writeByte(1);
    writer.write(obj.score);
    writer.writeByte(2);
    writer.write(obj.totalQuestions);
    writer.writeByte(3);
    writer.write(obj.skipped);
    writer.writeByte(4);
    writer.write(obj.mode);
    writer.writeByte(5);
    writer.write(obj.categoryCorrect);
    writer.writeByte(6);
    writer.write(obj.categoryTotal);
    writer.writeByte(7);
    writer.write(obj.avgTimeSeconds);
    writer.writeByte(8);
    writer.write(obj.attemptSnapshots);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;

  @override
  int get hashCode => typeId.hashCode;
}