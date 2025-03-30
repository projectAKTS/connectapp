const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.addDefaultFieldsToUsers = functions.https.onRequest(async (req, res) => {
  const usersCollection = admin.firestore().collection("users");

  try {
    const usersSnapshot = await usersCollection.get();
    const batch = admin.firestore().batch();

    usersSnapshot.forEach((doc) => {
      const userRef = usersCollection.doc(doc.id);
      batch.update(userRef, {
        bio: doc.data().bio || "No bio available yet.",
        name: doc.data().name || "",
        lastName: doc.data().lastName || "",
        profilePicture: doc.data().profilePicture || "",
        userName: doc.data().userName || "",
        postsCount: doc.data().postsCount || 0,
        followers: doc.data().followers || [],
        following: doc.data().following || [],
      });
    });

    await batch.commit();
    res.status(200).send("All users updated successfully with default fields.");
  } catch (error) {
    console.error("Error updating users: ", error);
    res.status(500).send("Error updating users.");
  }
});
