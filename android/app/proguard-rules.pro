# Keep all of Stripe’s pushProvisioning classes
-keep class com.stripe.android.pushProvisioning.** { *; }
-dontwarn com.stripe.android.pushProvisioning.**

# (Optional) If you hit other missing Stripe classes, keep the entire SDK:
-keep class com.stripe.android.** { *; }
-dontwarn com.stripe.android.**
