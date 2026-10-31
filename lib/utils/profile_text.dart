/// Signup used to store this literal as the bio, so it reads as real
/// content everywhere. Treat it as no bio.
const String legacyPlaceholderBio = 'No bio available yet.';

String placeholderBioToEmpty(String bio) =>
    bio.trim() == legacyPlaceholderBio ? '' : bio;
