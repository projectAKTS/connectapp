# Keep all of Stripe’s pushProvisioning classes
-keep class com.stripe.android.pushProvisioning.** { *; }
-dontwarn com.stripe.android.pushProvisioning.**

# (Optional) If you hit other missing Stripe classes, keep the entire SDK:
-keep class com.stripe.android.** { *; }
-dontwarn com.stripe.android.**

# flutter_callkit_incoming requires its Android classes to survive shrinking.
-keep class com.hiennv.flutter_callkit_incoming.** { *; }
