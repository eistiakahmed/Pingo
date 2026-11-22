# Preserve generic type signatures for Gson TypeToken reflection in release builds
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Keep flutter_local_notifications receivers, models, and anonymous TypeToken subclasses
-keep class com.dexterous.** { *; }
-keep interface com.dexterous.** { *; }

# Keep Gson and all TypeToken subclasses so ScheduledNotificationReceiver never fails in release APKs
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
