// GENERATED CODE - DO NOT MODIFY BY HAND
// Written manually to avoid build_runner dependency.
// Must stay in sync with session_record.dart field indices.

part of 'session_record.dart';

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
    );
  }

  @override
  void write(BinaryWriter writer, SessionRecord obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.score)
      ..writeByte(2)
      ..write(obj.totalQuestions)
      ..writeByte(3)
      ..write(obj.skipped)
      ..writeByte(4)
      ..write(obj.mode)
      ..writeByte(5)
      ..write(obj.categoryCorrect)
      ..writeByte(6)
      ..write(obj.categoryTotal)
      ..writeByte(7)
      ..write(obj.avgTimeSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
