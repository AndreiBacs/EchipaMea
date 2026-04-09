import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('ro'), Locale('hu')];
  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final value = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(value != null, 'AppLocalizations not found in context');
    return value!;
  }

  static final Map<String, Map<String, String>> _strings = {
    'ro': {
      'appTitle': 'EchipaMea',
      'homeTagline': 'Aplicatie pentru echipe mici de constructori',
      'selectRole': 'Selecteaza rolul',
      'continue': 'Continua',
      'language': 'Limba',
      'english': 'Engleza',
      'romanian': 'Romana',
      'hungarian': 'Maghiara',
      'foreman': 'Sef de echipa',
      'worker': 'Muncitor',
      'roleForemanDescription':
          'Seful de echipa gestioneaza echipele, aloca lucrari si urmareste progresul.',
      'roleWorkerDescription':
          'Muncitorul vede lucrarile alocate, actualizeaza statusul si raporteaza activitatea.',
      'profileTitle': 'Profil',
      'profileLanguageSection': 'Limba aplicatiei',
      'profilePersonalDataSection': 'Date personale',
      'profileEmailLabel': 'Email',
      'profileFullNameLabel': 'Nume complet',
      'profilePhoneLabel': 'Telefon',
      'profileJobTitleLabel': 'Functie',
      'profileSaveButton': 'Salveaza profilul',
      'profileSaved': 'Profil actualizat',
      'profileRequiredField': 'Acest camp este obligatoriu',
      'loginTitle': 'Autentificare',
      'foremanLoginSection': 'Autentificare sef de echipa',
      'foremanLoginHint':
          'Foloseste credentialele tale pentru a accesa panoul sefului de echipa. Modul mock este activ cand autentificarea backend nu este configurata.',
      'password': 'Parola',
      'signingIn': 'Se autentifica...',
      'loginAsForeman': 'Autentifica-te ca sef de echipa',
      'workerLoginSection': 'Autentificare muncitor',
      'workerLoginHint': 'Muncitorii trebuie sa scaneze codul QR generat de sef.',
      'scanQrToLogin': 'Scaneaza QR pentru autentificare',
      'termsAndConditions': 'Termeni si conditii',
      'pleaseEnterEmailAndPassword': 'Introdu emailul si parola.',
      'workerLoginTitle': 'Autentificare muncitor',
      'workerScanHint':
          'Scaneaza codul QR din panoul sefului de echipa pentru conectare automata.',
      'workerInvalidQr': 'Acesta nu este un cod QR valid pentru autentificare.',
      'workerConnected': 'Conectare reusita.',
      'workerQrReadError': 'Codul QR nu a putut fi citit. Incearca din nou.',
      'workerConnectedAs': 'Conectat ca',
      'employeeIdLabel': 'ID angajat',
      'foremanShellTitle': 'Sef de echipa',
      'logout': 'Deconectare',
      'dashboardTab': 'Panou',
      'mapTab': 'Harta',
      'projectsTab': 'Proiecte',
      'teamTab': 'Echipa',
      'clientsTab': 'Clienti',
      'profileTab': 'Profil',
      'navigation': 'Navigare',
      'quickEdit': 'Editare rapida',
      'quickQr': 'QR rapid',
      'editClientTooltip': 'Editeaza client',
      'editProjectTooltip': 'Editeaza proiect',
      'editEmployeeTooltip': 'Editeaza angajat',
      'generateLoginQrTooltip': 'Genereaza QR de login',
      'addClient': 'Adauga client',
      'addProject': 'Adauga proiect',
      'addEmployee': 'Adauga angajat',
      'appDownloadQr': 'QR descarcare aplicatie',
      'clientsTitle': 'Clienti',
      'projectsTitle': 'Proiecte',
      'employeesTitle': 'Angajati',
      'contactPersonLabel': 'Persoana de contact',
      'addressLabel': 'Adresa',
      'workerCountSuffix': 'muncitor(i)',
      'clientFormAddTitle': 'Adauga client',
      'clientFormEditTitle': 'Editeaza client',
      'clientNameLabel': 'Nume client',
      'activeProjectsLabel': 'Proiecte active',
      'personOfContactLabel': 'Persoana de contact',
      'cancel': 'Anuleaza',
      'saveChanges': 'Salveaza modificarile',
      'createClient': 'Creeaza client',
      'projectFormAddTitle': 'Adauga proiect',
      'projectFormEditTitle': 'Editeaza proiect',
      'projectNameLabel': 'Nume proiect',
      'statusLabel': 'Status',
      'workersCommaSeparatedLabel': 'Muncitori (separati prin virgula)',
      'createProject': 'Creeaza proiect',
      'employeeFormAddTitle': 'Adauga angajat',
      'employeeFormEditTitle': 'Editeaza angajat',
      'employeeNameLabel': 'Nume angajat',
      'roleLabel': 'Rol',
      'workingDaysLabel': 'Zile lucratoare',
      'workStartHourLabel': 'Ora inceput',
      'workEndHourLabel': 'Ora sfarsit',
      'workingScheduleLabel': 'Program',
      'weekdayMon': 'Lun',
      'weekdayTue': 'Mar',
      'weekdayWed': 'Mie',
      'weekdayThu': 'Joi',
      'weekdayFri': 'Vin',
      'weekdaySat': 'Sam',
      'weekdaySun': 'Dum',
      'createEmployee': 'Creeaza angajat',
      'statusPlanned': 'Planificat',
      'statusInProgress': 'In progres',
      'statusDone': 'Finalizat',
      'employeeLoginQrTitle': 'QR login angajat',
      'workerScansToConnect':
          'Muncitorul scaneaza acest cod pentru a se conecta automat.',
      'close': 'Inchide',
      'appDownloadQrTitle': 'QR descarcare aplicatie',
      'appDownloadMissingUrl':
          'APP_LANDING_URL sau APP_DOWNLOAD_URL trebuie setat in .env.',
      'appDownloadHintRouted':
          'Angajatii pot scana acest link unic. Poate directiona iOS catre TestFlight si Android catre APK.',
      'appDownloadHintDirect':
          'Angajatii pot scana cu camera telefonului pentru a incepe descarcarea aplicatiei.',
      'androidTargetSet': 'Destinatia Android este setata.',
      'iosTargetSet': 'Destinatia iOS este setata.',
      'downloadLinkCopied': 'Linkul de descarcare a fost copiat.',
      'copyLink': 'Copiaza linkul',
      'qrRenderError': 'Eroare la randarea codului QR',
      'termsIntro':
          'Prin utilizarea aplicatiei EchipaMea, esti de acord sa folosesti aplicatia doar pentru coordonare legala a lucrarilor si managementul echipei.',
      'termsSection1':
          '1. Conturi si roluri\nConturile de sef de echipa pot gestiona proiecte, echipe si clienti. Conturile de muncitor pot accesa doar sarcinile alocate.',
      'termsSection2':
          '2. Utilizarea datelor\nDatele despre proiecte si angajati trebuie sa fie corecte si actualizate doar de utilizatori autorizati.',
      'termsSection3':
          '3. Confidentialitate\nNu incarca date personale sensibile decat daca este necesar conform obligatiilor legale si politicilor companiei.',
      'termsSection4':
          '4. Login QR\nDatele de autentificare prin QR trebuie folosite doar de angajatul destinat si nu trebuie distribuite.',
      'termsSection5':
          '5. Modificari\nAcesti termeni pot fi actualizati in timp. Utilizarea continua a aplicatiei inseamna acceptarea actualizarilor viitoare.',
      'termsSection6':
          '6. GDPR\nEchipaMea prelucreaza datele personale in conformitate cu Regulamentul general privind protectia datelor (UE) 2016/679. Utilizatorii au dreptul de acces, rectificare sau stergere a datelor personale si pot solicita restrictionarea prelucrarii, in limitele obligatiilor legale aplicabile.',
      'inProgress': 'In progres',
      'assignments': 'Alocari',
      'totalWorkersAvailable': 'Total muncitori disponibili',
      'activeProjectsNow': 'Proiecte active acum',
      'workersWithActiveTasks': 'Muncitori cu sarcini active',
      'clientsWithActiveJobs': 'Clienti cu lucrari active',
      'whoDoesWhat': 'Cine ce face',
      'whoWorksOnWhatProject': 'Cine lucreaza pe ce proiect',
      'projectLabel': 'Proiect',
      'mapOverviewTitle': 'Harta proiecte si muncitori',
      'mapLegendProjects': 'Proiecte in progres',
      'mapLegendWorkers': 'Pozitii muncitori',
      'setupFlowTitle': 'Bun venit',
      'setupWelcomeHeadline': 'Coordoneaza-ti echipa',
      'setupWelcomeBody':
          'EchipaMea ajuta sefii de echipa sa gestioneze proiecte si echipe, iar muncitorii se conecteaza rapid prin scanare QR.',
      'setupLanguageHint':
          'Alege limba aplicatiei. O poti schimba oricand din Profil.',
      'setupRolesHeadline': 'Doua moduri de lucru',
      'setupRolesIntro':
          'In functie de rolul tau, vei folosi aplicatia altfel:',
      'setupBack': 'Inapoi',
      'setupNext': 'Inainte',
      'setupGetStarted': 'Incepe',
      'workerShellTitle': 'Lucrarile mele',
      'workerWorkTab': 'Lucrari',
      'workerProfileTab': 'Profil',
      'workerNoAssignments':
          'Nu ai lucrari alocate acum. Seful de echipa te va adauga pe un proiect.',
      'workerNextUp': 'Urmatoarea lucrare',
      'workerUpcomingWork': 'In continuare',
      'workerViewDetails': 'Vezi detalii',
      'workerProjectDetails': 'Detalii lucrare',
      'workerProjectNotFound': 'Lucrarea nu a fost gasita sau nu este alocata tie.',
      'workerCoordinatesHint': 'Coordonate site',
      'workerAssignedWorkersLabel': 'Echipa pe proiect',
      'workerOpenNavigation': 'Deschide navigatia',
      'workerAnnounceArrival': 'Am ajuns la locatie',
      'workerArrivalSent': 'Seful de echipa a fost anuntat ca ai ajuns.',
      'workerLocationMissing':
          'Nu exista coordonate pentru acest proiect; navigatia nu poate fi deschisa.',
      'workerCompleteWork': 'Finalizeaza lucrarea',
      'workerReportTitle': 'Raport de lucru',
      'workerReportPhotosStep': 'Poze de pe santier',
      'workerReportPhotosHint':
          'Adauga pana la 8 poze (optional). Treci mai departe daca nu ai.',
      'workerReportAddPhotos': 'Adauga poze',
      'workerReportMemoStep': 'Nota vocala',
      'workerReportMemoHint':
          'Inregistreaza un scurt mesaj vocal (optional).',
      'workerReportStartRecording': 'Incepe inregistrarea',
      'workerReportStopRecording': 'Opreste inregistrarea',
      'workerReportRecordingSaved': 'Memo salvat',
      'workerReportRecordingUnavailable':
          'Inregistrarea nu este disponibila pe acest dispozitiv.',
      'workerReportDescriptionStep': 'Descriere si trimitere',
      'workerReportDescriptionHint': 'Scurta descriere a lucrarilor',
      'workerReportSubmit': 'Trimite raportul',
      'workerReportSubmitted': 'Raport trimis. Multumim!',
      'workerReportNeedDescription': 'Adauga o scurta descriere inainte de trimitere.',
      'workerReportPhotoPickFailed': 'Nu am putut incarca pozele. Incearca din nou.',
      'workerReportMicPermission':
          'Permisiunea pentru microfon este necesara pentru memo.',
    },
    'hu': {
      'appTitle': 'EchipaMea',
      'homeTagline': 'Alkalmazas kis vallalkozoi csapatoknak',
      'selectRole': 'Szerepkor kivalasztasa',
      'continue': 'Folytatas',
      'language': 'Nyelv',
      'english': 'Angol',
      'romanian': 'Roman',
      'hungarian': 'Magyar',
      'foreman': 'Munkavezeto',
      'worker': 'Munkas',
      'roleForemanDescription':
          'A munkavezeto kezeli a csapatokat, kiosztja a feladatokat es koveti az elorehaladast.',
      'roleWorkerDescription':
          'A munkas latja a kiosztott feladatokat, frissiti az allapotot es jelenti az elvegzett munkat.',
      'profileTitle': 'Profil',
      'profileLanguageSection': 'Alkalmazas nyelve',
      'profilePersonalDataSection': 'Szemelyes adatok',
      'profileEmailLabel': 'Email',
      'profileFullNameLabel': 'Teljes nev',
      'profilePhoneLabel': 'Telefonszam',
      'profileJobTitleLabel': 'Beosztas',
      'profileSaveButton': 'Profil mentese',
      'profileSaved': 'Profil frissitve',
      'profileRequiredField': 'Ez a mezo kotelezo',
      'loginTitle': 'Bejelentkezes',
      'foremanLoginSection': 'Munkavezeto bejelentkezes',
      'foremanLoginHint':
          'A munkavezetoi felulet eleresehez add meg a hitelesito adataidat. Ha a backend hitelesites nincs beallitva, mock mod aktiv.',
      'password': 'Jelszo',
      'signingIn': 'Bejelentkezes...',
      'loginAsForeman': 'Bejelentkezes munkavezetokent',
      'workerLoginSection': 'Munkas bejelentkezes',
      'workerLoginHint':
          'A munkasoknak a munkavezeto altal generalt QR kodot kell beolvasniuk.',
      'scanQrToLogin': 'QR beolvasasa a bejelentkezeshez',
      'termsAndConditions': 'Felhasznalasi feltetelek',
      'pleaseEnterEmailAndPassword': 'Add meg az email cimet es a jelszot.',
      'workerLoginTitle': 'Munkas bejelentkezes',
      'workerScanHint':
          'A munkavezeto feluleterol szkenneld be a QR kodot az automatikus csatlakozashoz.',
      'workerInvalidQr': 'Ez nem ervenyes munkas bejelentkezo QR kod.',
      'workerConnected': 'Sikeres csatlakozas.',
      'workerQrReadError': 'A QR kod nem olvashato. Probald ujra.',
      'workerConnectedAs': 'Csatlakozva mint',
      'employeeIdLabel': 'Dolgozo azonosito',
      'foremanShellTitle': 'Munkavezeto',
      'logout': 'Kijelentkezes',
      'dashboardTab': 'Attekintes',
      'mapTab': 'Terkep',
      'projectsTab': 'Projektek',
      'teamTab': 'Csapat',
      'clientsTab': 'Ugyfelek',
      'profileTab': 'Profil',
      'navigation': 'Navigacio',
      'quickEdit': 'Gyors szerkesztes',
      'quickQr': 'Gyors QR',
      'editClientTooltip': 'Ugyfel szerkesztese',
      'editProjectTooltip': 'Projekt szerkesztese',
      'editEmployeeTooltip': 'Dolgozo szerkesztese',
      'generateLoginQrTooltip': 'Bejelentkezo QR generalasa',
      'addClient': 'Ugyfel hozzaadasa',
      'addProject': 'Projekt hozzaadasa',
      'addEmployee': 'Dolgozo hozzaadasa',
      'appDownloadQr': 'Alkalmazas letoltesi QR',
      'clientsTitle': 'Ugyfelek',
      'projectsTitle': 'Projektek',
      'employeesTitle': 'Dolgozok',
      'contactPersonLabel': 'Kapcsolattarto',
      'addressLabel': 'Cim',
      'workerCountSuffix': 'munkas',
      'clientFormAddTitle': 'Ugyfel hozzaadasa',
      'clientFormEditTitle': 'Ugyfel szerkesztese',
      'clientNameLabel': 'Ugyfel neve',
      'activeProjectsLabel': 'Aktiv projektek',
      'personOfContactLabel': 'Kapcsolattarto szemely',
      'cancel': 'Megse',
      'saveChanges': 'Valtozasok mentese',
      'createClient': 'Ugyfel letrehozasa',
      'projectFormAddTitle': 'Projekt hozzaadasa',
      'projectFormEditTitle': 'Projekt szerkesztese',
      'projectNameLabel': 'Projekt neve',
      'statusLabel': 'Allapot',
      'workersCommaSeparatedLabel': 'Munkasok (vesszovel elvalasztva)',
      'createProject': 'Projekt letrehozasa',
      'employeeFormAddTitle': 'Dolgozo hozzaadasa',
      'employeeFormEditTitle': 'Dolgozo szerkesztese',
      'employeeNameLabel': 'Dolgozo neve',
      'roleLabel': 'Szerep',
      'workingDaysLabel': 'Munkanapok',
      'workStartHourLabel': 'Kezdes',
      'workEndHourLabel': 'Befejezes',
      'workingScheduleLabel': 'Munkaido',
      'weekdayMon': 'Het',
      'weekdayTue': 'Ked',
      'weekdayWed': 'Sze',
      'weekdayThu': 'Csu',
      'weekdayFri': 'Pen',
      'weekdaySat': 'Szo',
      'weekdaySun': 'Vas',
      'createEmployee': 'Dolgozo letrehozasa',
      'statusPlanned': 'Tervezett',
      'statusInProgress': 'Folyamatban',
      'statusDone': 'Kesz',
      'employeeLoginQrTitle': 'Dolgozo bejelentkezo QR',
      'workerScansToConnect':
          'A munkas ezzel a koddal automatikusan tud csatlakozni.',
      'close': 'Bezaras',
      'appDownloadQrTitle': 'Alkalmazas letoltesi QR',
      'appDownloadMissingUrl':
          'Az APP_LANDING_URL vagy az APP_DOWNLOAD_URL erteket be kell allitani a .env fajlban.',
      'appDownloadHintRouted':
          'A dolgozok ezt az egy linket szkennelik. iOS-en TestFlight-ra, Androidon APK letoltesre iranyithat.',
      'appDownloadHintDirect':
          'A dolgozok a telefon kamerajaval szkennelve elkezdhetik az alkalmazas letolteset.',
      'androidTargetSet': 'Az Android cel URL be van allitva.',
      'iosTargetSet': 'Az iOS cel URL be van allitva.',
      'downloadLinkCopied': 'A letoltesi link masolva.',
      'copyLink': 'Link masolasa',
      'qrRenderError': 'QR renderelesi hiba',
      'termsIntro':
          'Az EchipaMea hasznalataval elfogadod, hogy az alkalmazast csak jogszeru munkaszervezesre es csapatmenedzsmentre hasznalod.',
      'termsSection1':
          '1. Fiokok es szerepkorok\nA munkavezeto fiokok kezelhetik a projekteket, csapatokat es ugyfeleket. A munkas fiokok csak a kijelolt feladatokhoz fernek hozza.',
      'termsSection2':
          '2. Adatkezeles\nA projekt- es dolgozoi adatoknak pontosnak kell lenniuk, es csak jogosult felhasznalok frissithetik oket.',
      'termsSection3':
          '3. Adatvedelem\nNe tolts fel erzekeny szemelyes adatokat, hacsak jogi kotelezettseg vagy ceges szabalyozas ezt nem irja elo.',
      'termsSection4':
          '4. QR bejelentkezes\nA QR bejelentkezesi adatokat csak a kijelolt dolgozo hasznalhatja, es nem szabad tovabbadni.',
      'termsSection5':
          '5. Valtozasok\nEzek a feltetelek idovel valtozhatnak. Az alkalmazas tovabbi hasznalata a jovobeli valtozasok elfogadasat jelenti.',
      'termsSection6':
          '6. GDPR\nAz EchipaMea a szemelyes adatokat a 2016/679 EU Altalanos Adatvedelmi Rendeletnek megfeleloen kezeli. A felhasznalokat megilleti a hozzaferes, helyesbites, torles, valamint az adatkezeles korlatozasanak kerese a vonatkozo jogszabalyi kotelezettsegek keretein belul.',
      'inProgress': 'Folyamatban',
      'assignments': 'Kiosztasok',
      'totalWorkersAvailable': 'Osszes elerheto munkas',
      'activeProjectsNow': 'Jelenleg aktiv projektek',
      'workersWithActiveTasks': 'Aktiv feladattal rendelkezo munkasok',
      'clientsWithActiveJobs': 'Aktiv munkaval rendelkezo ugyfelek',
      'whoDoesWhat': 'Ki mit csinal',
      'whoWorksOnWhatProject': 'Ki melyik projekten dolgozik',
      'projectLabel': 'Projekt',
      'mapOverviewTitle': 'Projekt es munkas terkep',
      'mapLegendProjects': 'Folyamatban levo projektek',
      'mapLegendWorkers': 'Munkas poziciok',
      'setupFlowTitle': 'Udvozlunk',
      'setupWelcomeHeadline': 'Szervezd a csapatodat',
      'setupWelcomeBody':
          'Az EchipaMea segit a munkavezetoknek a projektek es csapatok kezeleseben, a munkasok pedig gyorsan csatlakozhatnak QR szkennelessel.',
      'setupLanguageHint':
          'Valaszd ki az alkalmazas nyelvet. Kesobb barmikor megvaltoztathatod a Profilban.',
      'setupRolesHeadline': 'Ket hasznalati mod',
      'setupRolesIntro': 'A szerepedtol fuggoen igy fogod hasznalni az alkalmazast:',
      'setupBack': 'Vissza',
      'setupNext': 'Tovabb',
      'setupGetStarted': 'Inditas',
      'workerShellTitle': 'Munkaim',
      'workerWorkTab': 'Munkak',
      'workerProfileTab': 'Profil',
      'workerNoAssignments':
          'Jelenleg nincs kiosztott munkad. A munkavezeto hozzaad egy projekthez.',
      'workerNextUp': 'Kovetkezo munka',
      'workerUpcomingWork': 'Kesobb',
      'workerViewDetails': 'Reszletek',
      'workerProjectDetails': 'Munka reszletei',
      'workerProjectNotFound': 'A projekt nem talalhato vagy nincs hozzad rendelve.',
      'workerCoordinatesHint': 'Helyszin koordinatak',
      'workerAssignedWorkersLabel': 'Csapat a projekten',
      'workerOpenNavigation': 'Navigacio megnyitasa',
      'workerAnnounceArrival': 'Megérkeztem a helyszinre',
      'workerArrivalSent': 'A munkavezeto ertesult az erkezesrol.',
      'workerLocationMissing':
          'Ehhez a projekthez nincsenek koordinatak; a navigacio nem nyithato meg.',
      'workerCompleteWork': 'Munka befejezese',
      'workerReportTitle': 'Munkajelentes',
      'workerReportPhotosStep': 'Helyszini fenykepek',
      'workerReportPhotosHint':
          'Legfeljebb 8 kepet adhatsz hozza (opcionalis). Folytathatod ugy is, ha nincs.',
      'workerReportAddPhotos': 'Kepek hozzadasa',
      'workerReportMemoStep': 'Hangjegyzet',
      'workerReportMemoHint':
          'Rovid hangos uzenet (opcionalis).',
      'workerReportStartRecording': 'Felvetel inditasa',
      'workerReportStopRecording': 'Felvetel leallitasa',
      'workerReportRecordingSaved': 'Hangjegyzet elmentve',
      'workerReportRecordingUnavailable':
          'A felvetel nem elerheto ezen az eszkozon.',
      'workerReportDescriptionStep': 'Leiras es kuldes',
      'workerReportDescriptionHint': 'Rovid leiras a vegzett munkarol',
      'workerReportSubmit': 'Jelentes kuldese',
      'workerReportSubmitted': 'Jelentes elkuldve. Koszonjuk!',
      'workerReportNeedDescription': 'Adj meg rovid leirast a kuldes elott.',
      'workerReportPhotoPickFailed': 'A kepek nem tolthetok be. Probald ujra.',
      'workerReportMicPermission':
          'A hangjegyzethez mikrofon engedely szukseges.',
    },
    'en': {
      'appTitle': 'EchipaMea',
      'homeTagline': 'Small contractor app',
      'selectRole': 'Select role',
      'continue': 'Continue',
      'language': 'Language',
      'english': 'English',
      'romanian': 'Romanian',
      'hungarian': 'Hungarian',
      'foreman': 'Foreman',
      'worker': 'Worker',
      'roleForemanDescription':
          'Foreman manages crews, assigns jobs, and tracks progress.',
      'roleWorkerDescription':
          'Worker views assigned jobs, updates status, and logs completed work.',
      'profileTitle': 'Profile',
      'profileLanguageSection': 'App language',
      'profilePersonalDataSection': 'Personal data',
      'profileEmailLabel': 'Email',
      'profileFullNameLabel': 'Full name',
      'profilePhoneLabel': 'Phone',
      'profileJobTitleLabel': 'Job title',
      'profileSaveButton': 'Save profile',
      'profileSaved': 'Profile updated',
      'profileRequiredField': 'This field is required',
      'loginTitle': 'Login',
      'foremanLoginSection': 'Foreman login',
      'foremanLoginHint':
          'Use your credentials to access the foreman dashboard. Mock mode is active when backend auth is not configured.',
      'password': 'Password',
      'signingIn': 'Signing in...',
      'loginAsForeman': 'Login as Foreman',
      'workerLoginSection': 'Worker login',
      'workerLoginHint': 'Workers must scan the QR code generated by foreman.',
      'scanQrToLogin': 'Scan QR to Login',
      'termsAndConditions': 'Terms and Conditions',
      'pleaseEnterEmailAndPassword': 'Please enter email and password.',
      'workerLoginTitle': 'Worker Login',
      'workerScanHint':
          'Scan the QR code from foreman dashboard to connect automatically.',
      'workerInvalidQr': 'This is not a valid worker login QR code.',
      'workerConnected': 'Connected successfully.',
      'workerQrReadError': 'Could not read QR. Try again.',
      'workerConnectedAs': 'Connected as',
      'employeeIdLabel': 'Employee ID',
      'foremanShellTitle': 'Foreman',
      'logout': 'Logout',
      'dashboardTab': 'Dashboard',
      'mapTab': 'Map',
      'projectsTab': 'Projects',
      'teamTab': 'Team',
      'clientsTab': 'Clients',
      'profileTab': 'Profile',
      'navigation': 'Navigation',
      'quickEdit': 'Quick edit',
      'quickQr': 'Quick QR',
      'editClientTooltip': 'Edit client',
      'editProjectTooltip': 'Edit project',
      'editEmployeeTooltip': 'Edit employee',
      'generateLoginQrTooltip': 'Generate login QR',
      'addClient': 'Add client',
      'addProject': 'Add project',
      'addEmployee': 'Add employee',
      'appDownloadQr': 'App download QR',
      'clientsTitle': 'Clients',
      'projectsTitle': 'Projects',
      'employeesTitle': 'Employees',
      'contactPersonLabel': 'Contact person',
      'addressLabel': 'Address',
      'workerCountSuffix': 'worker(s)',
      'clientFormAddTitle': 'Add client',
      'clientFormEditTitle': 'Edit client',
      'clientNameLabel': 'Client name',
      'activeProjectsLabel': 'Active projects',
      'personOfContactLabel': 'Person of contact',
      'cancel': 'Cancel',
      'saveChanges': 'Save changes',
      'createClient': 'Create client',
      'projectFormAddTitle': 'Add project',
      'projectFormEditTitle': 'Edit project',
      'projectNameLabel': 'Project name',
      'statusLabel': 'Status',
      'workersCommaSeparatedLabel': 'Workers (comma separated)',
      'createProject': 'Create project',
      'employeeFormAddTitle': 'Add employee',
      'employeeFormEditTitle': 'Edit employee',
      'employeeNameLabel': 'Employee name',
      'roleLabel': 'Role',
      'workingDaysLabel': 'Working days',
      'workStartHourLabel': 'Start hour',
      'workEndHourLabel': 'End hour',
      'workingScheduleLabel': 'Schedule',
      'weekdayMon': 'Mon',
      'weekdayTue': 'Tue',
      'weekdayWed': 'Wed',
      'weekdayThu': 'Thu',
      'weekdayFri': 'Fri',
      'weekdaySat': 'Sat',
      'weekdaySun': 'Sun',
      'createEmployee': 'Create employee',
      'statusPlanned': 'Planned',
      'statusInProgress': 'In Progress',
      'statusDone': 'Done',
      'employeeLoginQrTitle': 'Employee login QR',
      'workerScansToConnect': 'Worker scans this code to connect automatically.',
      'close': 'Close',
      'appDownloadQrTitle': 'App download QR',
      'appDownloadMissingUrl':
          'APP_LANDING_URL or APP_DOWNLOAD_URL must be set in .env.',
      'appDownloadHintRouted':
          'Employees can scan this one link. It can route iOS to TestFlight and Android to APK.',
      'appDownloadHintDirect':
          'Employees can scan with their phone camera to start the app download.',
      'androidTargetSet': 'Android target is set.',
      'iosTargetSet': 'iOS target is set.',
      'downloadLinkCopied': 'Download link copied.',
      'copyLink': 'Copy link',
      'qrRenderError': 'QR render error',
      'termsIntro':
          'By using EchipaMea, you agree to use the app only for lawful work coordination and team management.',
      'termsSection1':
          '1. Accounts and Roles\nForeman accounts can manage projects, teams, and clients. Worker accounts can access assigned tasks only.',
      'termsSection2':
          '2. Data Usage\nProject and employee data should be accurate and updated by authorized users only.',
      'termsSection3':
          '3. Privacy\nDo not upload sensitive personal data unless required by your legal obligations and company policy.',
      'termsSection4':
          '4. QR Login\nQR login credentials must be used only by the intended employee and should not be shared.',
      'termsSection5':
          '5. Changes\nThese terms may be updated over time. Continued use of the app means you accept future updates.',
      'termsSection6':
          '6. GDPR\nEchipaMea processes personal data in line with the General Data Protection Regulation (EU) 2016/679. Users have the right to access, rectify, or erase their personal data and to request restrictions on processing, subject to applicable legal obligations.',
      'inProgress': 'In Progress',
      'assignments': 'Assignments',
      'totalWorkersAvailable': 'Total workers available',
      'activeProjectsNow': 'Active projects now',
      'workersWithActiveTasks': 'Workers with active tasks',
      'clientsWithActiveJobs': 'Clients with active jobs',
      'whoDoesWhat': 'Who does what',
      'whoWorksOnWhatProject': 'Who works on what project',
      'projectLabel': 'Project',
      'mapOverviewTitle': 'Projects and workers map',
      'mapLegendProjects': 'Projects in progress',
      'mapLegendWorkers': 'Worker positions',
      'setupFlowTitle': 'Welcome',
      'setupWelcomeHeadline': 'Run your crew with confidence',
      'setupWelcomeBody':
          'EchipaMea helps foremen manage projects and teams, while workers connect in seconds by scanning a QR code.',
      'setupLanguageHint':
          'Pick your app language. You can change it anytime in Profile.',
      'setupRolesHeadline': 'Two ways to use the app',
      'setupRolesIntro': 'Depending on your role, you will use the app differently:',
      'setupBack': 'Back',
      'setupNext': 'Next',
      'setupGetStarted': 'Get started',
      'workerShellTitle': 'My work',
      'workerWorkTab': 'Work',
      'workerProfileTab': 'Profile',
      'workerNoAssignments':
          'You have no jobs assigned yet. Your foreman will add you to a project.',
      'workerNextUp': 'Next up',
      'workerUpcomingWork': 'Coming up',
      'workerViewDetails': 'View details',
      'workerProjectDetails': 'Job details',
      'workerProjectNotFound': 'This job was not found or is not assigned to you.',
      'workerCoordinatesHint': 'Site coordinates',
      'workerAssignedWorkersLabel': 'Crew on this job',
      'workerOpenNavigation': 'Open navigation',
      'workerAnnounceArrival': 'I have arrived on site',
      'workerArrivalSent': 'Your foreman is notified that you arrived.',
      'workerLocationMissing':
          'This project has no coordinates; navigation cannot be opened.',
      'workerCompleteWork': 'Finish this job',
      'workerReportTitle': 'Work report',
      'workerReportPhotosStep': 'Site photos',
      'workerReportPhotosHint':
          'Add up to 8 photos (optional). You can skip if you have none.',
      'workerReportAddPhotos': 'Add photos',
      'workerReportMemoStep': 'Voice memo',
      'workerReportMemoHint': 'Record a short voice note (optional).',
      'workerReportStartRecording': 'Start recording',
      'workerReportStopRecording': 'Stop recording',
      'workerReportRecordingSaved': 'Memo saved',
      'workerReportRecordingUnavailable':
          'Recording is not available on this device.',
      'workerReportDescriptionStep': 'Description and submit',
      'workerReportDescriptionHint': 'Short summary of work done',
      'workerReportSubmit': 'Submit report',
      'workerReportSubmitted': 'Report sent. Thank you!',
      'workerReportNeedDescription': 'Add a short description before submitting.',
      'workerReportPhotoPickFailed': 'Could not pick photos. Try again.',
      'workerReportMicPermission':
          'Microphone permission is required for a voice memo.',
    },
  };

  String _t(String key) {
    return _strings[locale.languageCode]?[key] ?? _strings['en']![key]!;
  }

  String get appTitle => _t('appTitle');
  String get homeTagline => _t('homeTagline');
  String get selectRole => _t('selectRole');
  String get continueLabel => _t('continue');
  String get language => _t('language');
  String get english => _t('english');
  String get romanian => _t('romanian');
  String get hungarian => _t('hungarian');
  String get foreman => _t('foreman');
  String get worker => _t('worker');
  String get roleForemanDescription => _t('roleForemanDescription');
  String get roleWorkerDescription => _t('roleWorkerDescription');
  String get profileTitle => _t('profileTitle');
  String get profileLanguageSection => _t('profileLanguageSection');
  String get profilePersonalDataSection => _t('profilePersonalDataSection');
  String get profileEmailLabel => _t('profileEmailLabel');
  String get profileFullNameLabel => _t('profileFullNameLabel');
  String get profilePhoneLabel => _t('profilePhoneLabel');
  String get profileJobTitleLabel => _t('profileJobTitleLabel');
  String get profileSaveButton => _t('profileSaveButton');
  String get profileSaved => _t('profileSaved');
  String get profileRequiredField => _t('profileRequiredField');
  String get loginTitle => _t('loginTitle');
  String get foremanLoginSection => _t('foremanLoginSection');
  String get foremanLoginHint => _t('foremanLoginHint');
  String get password => _t('password');
  String get signingIn => _t('signingIn');
  String get loginAsForeman => _t('loginAsForeman');
  String get workerLoginSection => _t('workerLoginSection');
  String get workerLoginHint => _t('workerLoginHint');
  String get scanQrToLogin => _t('scanQrToLogin');
  String get termsAndConditions => _t('termsAndConditions');
  String get pleaseEnterEmailAndPassword => _t('pleaseEnterEmailAndPassword');
  String get workerLoginTitle => _t('workerLoginTitle');
  String get workerScanHint => _t('workerScanHint');
  String get workerInvalidQr => _t('workerInvalidQr');
  String get workerConnected => _t('workerConnected');
  String get workerQrReadError => _t('workerQrReadError');
  String get workerConnectedAs => _t('workerConnectedAs');
  String get employeeIdLabel => _t('employeeIdLabel');
  String get foremanShellTitle => _t('foremanShellTitle');
  String get logout => _t('logout');
  String get dashboardTab => _t('dashboardTab');
  String get mapTab => _t('mapTab');
  String get projectsTab => _t('projectsTab');
  String get teamTab => _t('teamTab');
  String get clientsTab => _t('clientsTab');
  String get profileTab => _t('profileTab');
  String get navigation => _t('navigation');
  String get quickEdit => _t('quickEdit');
  String get quickQr => _t('quickQr');
  String get editClientTooltip => _t('editClientTooltip');
  String get editProjectTooltip => _t('editProjectTooltip');
  String get editEmployeeTooltip => _t('editEmployeeTooltip');
  String get generateLoginQrTooltip => _t('generateLoginQrTooltip');
  String get addClient => _t('addClient');
  String get addProject => _t('addProject');
  String get addEmployee => _t('addEmployee');
  String get appDownloadQr => _t('appDownloadQr');
  String get clientsTitle => _t('clientsTitle');
  String get projectsTitle => _t('projectsTitle');
  String get employeesTitle => _t('employeesTitle');
  String get contactPersonLabel => _t('contactPersonLabel');
  String get addressLabel => _t('addressLabel');
  String get workerCountSuffix => _t('workerCountSuffix');
  String get clientFormAddTitle => _t('clientFormAddTitle');
  String get clientFormEditTitle => _t('clientFormEditTitle');
  String get clientNameLabel => _t('clientNameLabel');
  String get activeProjectsLabel => _t('activeProjectsLabel');
  String get personOfContactLabel => _t('personOfContactLabel');
  String get cancel => _t('cancel');
  String get saveChanges => _t('saveChanges');
  String get createClient => _t('createClient');
  String get projectFormAddTitle => _t('projectFormAddTitle');
  String get projectFormEditTitle => _t('projectFormEditTitle');
  String get projectNameLabel => _t('projectNameLabel');
  String get statusLabel => _t('statusLabel');
  String get workersCommaSeparatedLabel => _t('workersCommaSeparatedLabel');
  String get createProject => _t('createProject');
  String get employeeFormAddTitle => _t('employeeFormAddTitle');
  String get employeeFormEditTitle => _t('employeeFormEditTitle');
  String get employeeNameLabel => _t('employeeNameLabel');
  String get roleLabel => _t('roleLabel');
  String get workingDaysLabel => _t('workingDaysLabel');
  String get workStartHourLabel => _t('workStartHourLabel');
  String get workEndHourLabel => _t('workEndHourLabel');
  String get workingScheduleLabel => _t('workingScheduleLabel');
  String get weekdayMon => _t('weekdayMon');
  String get weekdayTue => _t('weekdayTue');
  String get weekdayWed => _t('weekdayWed');
  String get weekdayThu => _t('weekdayThu');
  String get weekdayFri => _t('weekdayFri');
  String get weekdaySat => _t('weekdaySat');
  String get weekdaySun => _t('weekdaySun');
  String get createEmployee => _t('createEmployee');
  String get statusPlanned => _t('statusPlanned');
  String get statusInProgress => _t('statusInProgress');
  String get statusDone => _t('statusDone');
  String get employeeLoginQrTitle => _t('employeeLoginQrTitle');
  String get workerScansToConnect => _t('workerScansToConnect');
  String get close => _t('close');
  String get appDownloadQrTitle => _t('appDownloadQrTitle');
  String get appDownloadMissingUrl => _t('appDownloadMissingUrl');
  String get appDownloadHintRouted => _t('appDownloadHintRouted');
  String get appDownloadHintDirect => _t('appDownloadHintDirect');
  String get androidTargetSet => _t('androidTargetSet');
  String get iosTargetSet => _t('iosTargetSet');
  String get downloadLinkCopied => _t('downloadLinkCopied');
  String get copyLink => _t('copyLink');
  String get qrRenderError => _t('qrRenderError');
  String get termsIntro => _t('termsIntro');
  String get termsSection1 => _t('termsSection1');
  String get termsSection2 => _t('termsSection2');
  String get termsSection3 => _t('termsSection3');
  String get termsSection4 => _t('termsSection4');
  String get termsSection5 => _t('termsSection5');
  String get termsSection6 => _t('termsSection6');
  String get inProgress => _t('inProgress');
  String get assignments => _t('assignments');
  String get totalWorkersAvailable => _t('totalWorkersAvailable');
  String get activeProjectsNow => _t('activeProjectsNow');
  String get workersWithActiveTasks => _t('workersWithActiveTasks');
  String get clientsWithActiveJobs => _t('clientsWithActiveJobs');
  String get whoDoesWhat => _t('whoDoesWhat');
  String get whoWorksOnWhatProject => _t('whoWorksOnWhatProject');
  String get projectLabel => _t('projectLabel');
  String get mapOverviewTitle => _t('mapOverviewTitle');
  String get mapLegendProjects => _t('mapLegendProjects');
  String get mapLegendWorkers => _t('mapLegendWorkers');
  String get setupFlowTitle => _t('setupFlowTitle');
  String get setupWelcomeHeadline => _t('setupWelcomeHeadline');
  String get setupWelcomeBody => _t('setupWelcomeBody');
  String get setupLanguageHint => _t('setupLanguageHint');
  String get setupRolesHeadline => _t('setupRolesHeadline');
  String get setupRolesIntro => _t('setupRolesIntro');
  String get setupBack => _t('setupBack');
  String get setupNext => _t('setupNext');
  String get setupGetStarted => _t('setupGetStarted');
  String get workerShellTitle => _t('workerShellTitle');
  String get workerWorkTab => _t('workerWorkTab');
  String get workerProfileTab => _t('workerProfileTab');
  String get workerNoAssignments => _t('workerNoAssignments');
  String get workerNextUp => _t('workerNextUp');
  String get workerUpcomingWork => _t('workerUpcomingWork');
  String get workerViewDetails => _t('workerViewDetails');
  String get workerProjectDetails => _t('workerProjectDetails');
  String get workerProjectNotFound => _t('workerProjectNotFound');
  String get workerCoordinatesHint => _t('workerCoordinatesHint');
  String get workerAssignedWorkersLabel => _t('workerAssignedWorkersLabel');
  String get workerOpenNavigation => _t('workerOpenNavigation');
  String get workerAnnounceArrival => _t('workerAnnounceArrival');
  String get workerArrivalSent => _t('workerArrivalSent');
  String get workerLocationMissing => _t('workerLocationMissing');
  String get workerCompleteWork => _t('workerCompleteWork');
  String get workerReportTitle => _t('workerReportTitle');
  String get workerReportPhotosStep => _t('workerReportPhotosStep');
  String get workerReportPhotosHint => _t('workerReportPhotosHint');
  String get workerReportAddPhotos => _t('workerReportAddPhotos');
  String get workerReportMemoStep => _t('workerReportMemoStep');
  String get workerReportMemoHint => _t('workerReportMemoHint');
  String get workerReportStartRecording => _t('workerReportStartRecording');
  String get workerReportStopRecording => _t('workerReportStopRecording');
  String get workerReportRecordingSaved => _t('workerReportRecordingSaved');
  String get workerReportRecordingUnavailable =>
      _t('workerReportRecordingUnavailable');
  String get workerReportDescriptionStep => _t('workerReportDescriptionStep');
  String get workerReportDescriptionHint => _t('workerReportDescriptionHint');
  String get workerReportSubmit => _t('workerReportSubmit');
  String get workerReportSubmitted => _t('workerReportSubmitted');
  String get workerReportNeedDescription => _t('workerReportNeedDescription');
  String get workerReportPhotoPickFailed => _t('workerReportPhotoPickFailed');
  String get workerReportMicPermission => _t('workerReportMicPermission');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
