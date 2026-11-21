## Politique de confidentialité (ÉBAUCHE, non publiée)

_Dernière mise à jour : [DATE]_

La présente politique explique quels renseignements personnels Kindupp
recueille, pourquoi, à qui ils sont communiqués et quels sont vos droits.
Elle est rédigée en fonction de la LPRPDE (Canada) et de la Loi sur la
protection des renseignements personnels dans le secteur privé du Québec
(Loi 25). [RÉVISION JURIDIQUE]

### Qui est responsable
Kindupp est exploité par [NOM LÉGAL DE L'ENTREPRISE INDIVIDUELLE / NOM
D'ENTREPRISE], [VILLE], Québec. [À VÉRIFIER : immatriculation]

**Personne responsable de la protection des renseignements personnels :**
[TITRE, p. ex. « Fondateur »] — [COURRIEL DE CONTACT CONFIDENTIALITÉ]
[NE PAS publier de coordonnées personnelles sans l'approbation du fondateur]

### Ce que nous recueillons
- **Compte :** nom, adresse courriel, mode de connexion (courriel, Google ou
  Apple).
- **Profil :** photo, bio, ville, pays, fuseau horaire, langues que vous
  parlez, sujets pour lesquels vous cherchez de l'aide, expérience que vous
  pouvez partager, disponibilités.
- **Contenu que vous créez :** publications, commentaires, messages et
  pièces jointes (photos, vidéos), avis donnés après une séance réservée.
- **Appels :** qui a appelé qui, quand, type et statut de l'appel. L'audio
  et la vidéo des appels ne sont ni enregistrés ni conservés par Kindupp.
- **Réservations et renseignements liés aux paiements :** consultations
  gratuites et dossiers connexes. Le code Phase 3 de l'application et des
  Cloud Functions désactive par défaut la perception de paiements, la
  configuration de cartes, les abonnements et les versements; le déploiement
  de production n'a pas été vérifié. Des fonctions de paiement activées
  antérieurement ou séparément peuvent créer des références client Stripe,
  moyen de paiement, PaymentIntent, compte connecté, consultation et
  versement. [VÉRIFIER l'état de production et les champs conservés avant
  publication; confirmer aussi l'affichage et la conservation par Stripe.]
- **Déclaration d'âge :** votre confirmation d'avoir 18 ans ou plus, avec
  sa date. Nous ne recueillons ni votre date de naissance ni de pièce
  d'identité.
- **Sécurité :** signalements que vous faites ou qui vous concernent, et
  personnes que vous avez bloquées.
- **Appareil :** jetons de notification et identifiant d'installation
  aléatoire, pour vous livrer messages et appels; langue de l'application,
  pour vous écrire les notifications dans cette langue.
- **Rapports de plantage (facultatif, désactivé par défaut) :** si vous
  activez « Envoyer les rapports de plantage », les détails techniques des
  plantages (modèle d'appareil, versions du système et de l'application,
  erreur). Non associés à votre compte.
- **Statistiques d'utilisation (facultatif, désactivé par défaut) :** si
  vous activez « Partager les statistiques d'utilisation », les écrans et
  fonctions utilisés. Non associées à votre compte; elles n'incluent jamais
  vos messages ni vos publications. Aucun identifiant publicitaire n'est
  recueilli.

Nous n'utilisons pas vos renseignements à des fins publicitaires et nous ne
les vendons pas.

### Pourquoi nous les utilisons
- Pour faire fonctionner Kindupp : comptes, profils, mise en relation
  selon les sujets et les langues, publications, messages, appels,
  réservations et paiements.
- Pour assurer la sécurité de la communauté : modération, signalements,
  blocage, prévention des abus et de la fraude.
- Pour envoyer les notifications que vous avez activées.
- Si vous y consentez : pour corriger les plantages et améliorer
  l'application.

### À qui ils sont communiqués (fournisseurs de services)
| Fournisseur | Finalité | Données | Lieu |
|---|---|---|---|
| Google Firebase (Authentication, Cloud Firestore, Cloud Storage, Cloud Functions, Cloud Messaging, App Check, Hosting) | Comptes, base de données, fichiers, logique serveur, notifications, protection contre les abus, site Web | Toutes les données ci-dessus | [À VÉRIFIER : région, p. ex. États-Unis] |
| Google Firebase Crashlytics / Analytics | Rapports de plantage / statistiques, seulement si vous les activez | Données d'appareil et d'utilisation ci-dessus | États-Unis [À VÉRIFIER] |
| Apple (APNs, PushKit, Se connecter avec Apple) et Google (FCM, connexion Google) | Notifications, appels entrants, connexion | Jetons d'appareil, identité de connexion | États-Unis |
| Google Cloud Vision SafeSearch | Vérification automatisée des images de publications et d'une vignette/d'une image vidéo; le code examiné n'envoie pas les médias de clavardage | Image de publication ou image vidéo soumise; résultat ajouté aux champs de modération | Point de terminaison Vision mondial; région et conditions [À VÉRIFIER] |
| Agora | Appels audio et vidéo en temps réel; aucun enregistrement trouvé dans le code client examiné | Médias d'appel en transit et métadonnées | [À VÉRIFIER : routage, télémétrie, régions et conditions] |
| Stripe | Moyens de paiement, paiements et versements si activés | Renseignements de paiement et de versement, identifiants fournisseur | [À VÉRIFIER : pays, état d'activation et conditions] |
| Netlify Forms | Formulaire de contact du site | Nom, courriel, sujet et message | [À VÉRIFIER : lieu, accès, conservation et suppression] |

Les autres utilisateurs voient votre profil public, vos publications et
commentaires, ainsi que les messages que vous leur envoyez.

### Communication à l'extérieur du Québec et du Canada
Nos fournisseurs traitent et conservent des renseignements à l'extérieur du
Québec, notamment aux États-Unis, où ils peuvent être accessibles aux
autorités selon les lois locales. Avant publication, confirmer l'évaluation
requise des protections liées à ces communications et si elle a été réalisée.
[RÉVISION JURIDIQUE]

### Durée de conservation
- **Suppression de compte :** l'application lance un processus de suppression
  côté serveur. Le code examiné supprime le compte Auth, le profil et ses
  sous-collections, les publications créées et leurs sous-collections,
  certaines références et les médias utilisateur/publication. Une
  suppression incomplète est consignée pour une nouvelle tentative
  planifiée. Le code ne fixe pas de délai total et le nettoyage peut rester
  incomplet après des tentatives. [Ne pas promettre une suppression immédiate
  ou sous 30 jours; confirmer le fonctionnement et le délai avant publication.]
- **Conservé après la suppression :**
  - Les messages envoyés restent dans les conversations des destinataires.
  - Les étoiles des avis restent dans la moyenne de la personne-ressource,
    sans votre nom; les commentaires d'avis sont supprimés. Les avis vous
    concernant en tant que personne-ressource sont supprimés.
  - Vos commentaires sur les publications des autres sont supprimés (ou
    vidés si d'autres y ont répondu), et votre nom est retiré des registres
    d'appels.
  - Les messages et médias de clavardage restent dans la conversation de
    l'autre participant; le code de suppression ne supprime pas les
    signalements ni les invitations d'appel.
  - Les dossiers de consultation/paiement, références Stripe, journaux des
    fournisseurs et sauvegardes peuvent subsister; leur durée et les outils
    de suppression ne sont pas confirmés.
- **Rapports de plantage et statistiques :** les commandes facultatives sont
  désactivées par défaut dans le code examiné. La conservation chez les
  fournisseurs n'a pas été vérifiée; ne pas préciser de durée avant la
  vérification des paramètres du projet.

### Données facultatives : comment nous vous le demandons
Après l'inscription, nous vous demandons une seule fois, séparément, si
vous voulez partager les rapports de plantage et les statistiques
d'utilisation. Les deux sont désactivés sauf si vous les activez, et
refuser ne change rien d'autre. Vous pouvez modifier ces choix en tout
temps dans les Paramètres.

### Vos choix et vos droits
- Dans l'application, vous pouvez :
  - consulter et modifier votre profil;
  - changer la langue de l'application;
  - activer ou désactiver les rapports de plantage et les statistiques;
  - bloquer des personnes;
  - supprimer votre compte.
- Écrivez à [COURRIEL DE CONTACT CONFIDENTIALITÉ] pour accéder à vos
  renseignements, les faire rectifier, retirer votre consentement ou poser
  une question. [Confirmer le processus de réponse et les délais applicables
  avant publication.]
- Vous pouvez porter plainte auprès de la Commission d'accès à
  l'information du Québec ou du Commissariat à la protection de la vie
  privée du Canada.

### Âge
Kindupp s'adresse aux personnes de 18 ans et plus. L'application utilise
une déclaration personnelle; le code examiné ne vérifie pas l'âge à l'aide
d'une pièce d'identité ou d'une date de naissance. [Confirmer la politique
18+ et la procédure pour les comptes de mineurs.]

### Incidents de confidentialité
Nous traiterons les incidents de confidentialité et les avis requis par la
loi. [VÉRIFIER le processus de réponse aux incidents et faire réviser ce texte
par un juriste.]

### Modifications
Nous vous informerons dans l'application de tout changement important à la
présente politique.

### Contact
[COURRIEL DE CONTACT CONFIDENTIALITÉ] · support@kindupp.ca
