package com.example.ytoffline.yt_offline

// audio_service requires the host Activity to be `AudioServiceActivity`
// (which itself extends `FlutterFragmentActivity`). Plain `FlutterActivity`
// causes audio_service.init to throw with "The Activity class declared in
// your AndroidManifest.xml is wrong or has not provided the correct
// FlutterEngine".
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity()
