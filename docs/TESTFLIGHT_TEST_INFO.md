# TestFlight Test Information (draft, not entered)

Prepared 2026-11-05 for App Store Connect › Helperly 2026 February ›
TestFlight › **Test Information**. Nothing here has been entered in App
Store Connect yet.

The page is required before an **external group** and a **public
invitation link** can exist: Apple reviews the first external build
(Beta App Review) using these fields.

## Current State (read-only check, 2026-11-05)

- Every field on the page is empty. The only localization is English
  (Canada); French has to be added (`French (Canada)`).
- One group, **Beta Testers** (internal, 2 team members). No external
  group, no public link.
- Latest build `1.0.2 (202611040659)`: ready to test, expires in 89 days.
- `Info.plist` has no `ITSAppUsesNonExemptEncryption` key, so every
  build waits for a manual export-compliance answer (two builds were left
  at "Missing Compliance"). Adding the key needs the founder's yes.

## Blockers (founder)

| Field | Needs |
|---|---|
| Feedback Email | the monitored `support@` address |
| Privacy Policy URL | production hosting deployed (for example `https://connectapp-278b4.web.app/privacy.html`, or a custom domain). `public/privacy.html` is English only today: a French page is needed for Québec |
| Review contact | the founder's name, phone and email, typed by the founder |
| Sign-in information | a demo account in **production** (see below); needs the founder's approval |

## Fields To Enter

Limits: description, review notes and "What to Test" 4,000 characters
each.

### Beta App Description: Français (Canada)

> Helperly met en relation des personnes qui ont vécu une situation
> (logement, emploi, études, démarches au Québec) avec celles qui la
> vivent maintenant. L’aide se fait par messages ou par appel audio ou
> vidéo.
>
> Cette bêta privée est gratuite et réservée aux 18 ans et plus. Les
> personnes qui aident partagent leur expérience personnelle : ce n’est
> pas un avis juridique, médical, financier ou d’immigration.
>
> Sécurité : n’envoyez jamais d’argent, de codes ou de mots de passe.
> Avec une personne inconnue, les photos, les liens et les appels
> deviennent possibles après sa réponse. Dans chaque conversation, vous
> pouvez signaler ou bloquer.
>
> Vous pouvez supprimer votre compte à tout moment : Profil › Paramètres ›
> Supprimer le compte.

### Beta App Description: English (Canada)

> Helperly connects people who have been through something (housing,
> jobs, school, getting settled in Québec) with people going through it
> now. Help happens by message or by audio or video call.
>
> This private beta is free and for people 18 and older. Helpers share
> their personal experience: it is not legal, medical, financial or
> immigration advice.
>
> Safety: never send money, codes or passwords. With someone you don't
> know, photos, links and calls unlock after they reply. In every chat
> you can report or block.
>
> You can delete your account at any time: Profile › Settings › Delete
> account.

### Feedback Email, Privacy Policy URL (both languages)

- Feedback Email: `[support@…]`
- Marketing URL: leave empty.
- Privacy Policy URL: `[FR page]` for French, `[EN page]` for English.

### Sign-In Information (for Apple's reviewer)

- **Sign-in required:** yes.
- Two production accounts, created by the founder or with his approval,
  on his own Gmail aliases (for example `yakupusamea+hb-review@gmail.com`
  and `yakupusamea+hb-review-helper@gmail.com`):
  1. **reviewer**: declared 18+, profile filled, used by Apple;
  2. **helper**: a helper profile Apple can find and write to, so chat
     and first-contact safety can be seen.
- Store the passwords only in App Store Connect and the founder's
  password manager, never in the repo.

### Review Notes (English; Apple reviews in English)

> Helperly is a free, invite-only beta for peer help in Montréal (EN/FR).
> Payments are disabled in this build.
>
> Sign in with the demo account above. On first launch the app asks for a
> one-time 18+ declaration; please confirm it.
>
> To try chat: open the helper profile "[helper display name]" from Home
> or Search and send a message. Until the other person replies, only
> text without links can be sent (first-contact safety). Audio and video
> calls (Agora) need a second signed-in device; the helper account can
> be used for that.
>
> User-generated content safeguards (Guideline 1.2): report and block
> from every chat (banner buttons and ⋮ menu) and from posts; reports
> are reviewed by the operator daily; received photos are blurred until
> tapped; post photos are checked automatically and sensitive ones are
> blurred or hidden.
>
> Account deletion (Guideline 5.1.1(v)): Profile › Settings › Delete
> account. It deletes the account and the user's data on the server;
> messages already sent stay with the other person, as the app states.
>
> Contact: [support@…].

### What To Test (per build; FR and EN)

Shown to testers when a build is added to the external group.

> **FR :** Créez votre profil, écrivez à une personne qui aide, puis
> essayez un appel audio ou vidéo. Signalez tout ce qui ne fonctionne
> pas ou vous met mal à l’aise : capture d’écran dans TestFlight, ou
> écrivez à [support@…].

> **EN:** Set up your profile, message a helper, then try an audio or
> video call. Report anything that breaks or feels wrong: take a
> screenshot in TestFlight, or write to [support@…].

## Order Once The Blockers Are Cleared

1. Founder: fill the support address and privacy URLs; Claude replaces
   the placeholders here and in `docs/BETA_INVITATION.md`.
2. Founder approves the two demo accounts; they are created and
   checked on the iPhone.
3. Claude enters the fields (EN and FR) in App Store Connect after the
   founder's go-ahead, then creates an external group, adds the latest
   build and submits it for Beta App Review (founder's yes first).
4. After approval: enable the public link, limit it (for example 25
   testers), and put it in the invitation.
