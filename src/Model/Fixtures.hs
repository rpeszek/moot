{-# LANGUAGE StrictData #-}

module Model.Fixtures where

import Import

import Text.Email.QuasiQuotation

data UserFixtures =
  UserFixtures { allUsersF :: [Entity User] }
  deriving (Eq, Show)

data OwnerFixtures =
  OwnerFixtures { allOwnersF :: [Entity Owner] }
  deriving (Eq, Show)

data AccountFixtures =
  AccountFixtures { allAccountsF :: [Entity Account] }
  deriving (Eq, Show)

data ConferenceFixtures =
  ConferenceFixtures { allConferencesF :: [Entity Conference] }
  deriving (Eq, Show)

data AbstractFixtures =
  AbstractFixtures { allAbstractsF :: [Entity Abstract] }
  deriving (Eq, Show)

data AbstractTypeFixtures =
  AbstractTypeFixtures { allAbstractTypesF :: [Entity AbstractType] }
  deriving (Eq, Show)

data Fixtures =
  Fixtures { userF :: UserFixtures
           , ownerF :: OwnerFixtures
           , accountF :: AccountFixtures
           , conferenceF :: ConferenceFixtures
           , abstractTypeF :: AbstractTypeFixtures
           , abstractF :: AbstractFixtures
           }
  deriving (Eq, Show)

chrisEmail :: Email
chrisEmail = [email|chris@lol.com|]
chrisPassword :: Text
chrisPassword = "chrisPass"

alexeyEmail :: Email
alexeyEmail = [email|alexey@lol.com|]
alexeyPassword :: Text
alexeyPassword = "alexeyPass"

waddlestonEmail :: Email
waddlestonEmail = [email|waddleston@lol.com|]
waddlestonPassword :: Text
waddlestonPassword = "waddlesPass"

doNothingEmail :: Email
doNothingEmail = [email|nothing@lol.com|]
doNothingPassword :: Text
doNothingPassword = "nothingPass"

makeAccount :: Email -> Text -> Text -> DB (Entity User, Entity Owner, Entity Account)
makeAccount email' name pass = do
  createAccount email' name pass

makeAccounts :: DB ([Entity User], [Entity Owner], [Entity Account])
makeAccounts =
  unzip3 <$>
  sequenceA [ makeAccount chrisEmail "Chris Allen" chrisPassword
            , makeAccount alexeyEmail "Alexey" alexeyPassword
            ]

makeUser :: Email -> Text -> Text -> DB (Entity User)
makeUser email' name pass = do
  createUser email' name pass

makeUsers :: DB [Entity User]
makeUsers =
  sequenceA [ makeUser waddlestonEmail "Waddles" waddlestonPassword
            , makeUser doNothingEmail "Know Nothing" doNothingPassword
            ]

{-# INLINABLE unsafeIdx #-}
unsafeIdx :: (MonoFoldable c) => c -> Integer -> Element c
unsafeIdx xs n
  | n < 0     = error "negative index"
  | otherwise =
    foldr (\x r k -> case k of
                       0 -> x
                       _ -> r (k-1)) (error ("index too large: " ++ show n))  xs n

makeConference :: AccountId
               -> Maybe UTCTime
               -> Maybe UTCTime
               -> Text
               -> DB (Entity Conference)
makeConference accountId openingTime closingTime confName =
  createConferenceForAccount
    accountId confName
    "The coolest code conf"
    (Markdown [st|
# You are submitting to the best conf

![](https://i.imgur.com/CzTosV9.jpg)

Thank you for submitting to this conf!
|])
    openingTime closingTime

makeAbstractType :: ConferenceId
                 -> TalkDuration
                 -> Text
                 -> DB (Entity AbstractType)
makeAbstractType abstractTypeConference
                 abstractTypeDuration
                 abstractTypeName =
  insertEntity AbstractType{..}

markdownifiedAbstractBody :: Markdown
markdownifiedAbstractBody = Markdown [st|
# Bananas, Lenses and Barbreh Strysen

```haskell
conferenceAbstractView (Entity confId conference)
  (Entity abstractId Abstract{..}) widget enctype = do
  abstractMarkdown <- renderMarkdown abstractAuthorAbstract
  abstractEditedMarkdown <-
    traverse renderMarkdown abstractEditedAbstract
```

Edited abstract 2
|]

makeAbstract' :: UserId
              -> AbstractTypeId
              -> Text
              -> Abstract
makeAbstract' abstractUser abstractAbstractType abstractAuthorTitle =
  let abstractAuthorAbstract = markdownifiedAbstractBody
      abstractEditedTitle = Nothing
      abstractEditedAbstract = Nothing
      abstractBlocked = False
  in Abstract{..}

makeAbstract :: UserId
             -> AbstractTypeId
             -> Text
             -> DB (Entity Abstract)
makeAbstract abstractUser abstractAbstractType abstractAuthorTitle =
  insertEntity $ makeAbstract' abstractUser abstractAbstractType abstractAuthorTitle

pastTime :: Maybe UTCTime
pastTime = Just $ UTCTime (fromGregorian 2017 1 1) 0

futureTime :: Maybe UTCTime
futureTime = Just $ UTCTime (fromGregorian 2019 1 1) 0

insertFixtures :: DB Fixtures
insertFixtures = do
  (accountUsersF, allOwnersF, allAccountsF) <- makeAccounts
  plainUsersF <- makeUsers
  let allUsersF = accountUsersF <> plainUsersF
      chrisAccount = unsafeIdx allAccountsF 0
      chrisAccountK = entityKey chrisAccount
      alexeyAccount = unsafeIdx allAccountsF 1
      alexeyAccountK = entityKey alexeyAccount
      waddlesUser = unsafeIdx plainUsersF 0
      waddlesUserK = entityKey waddlesUser

  chrisConferencesOpen <-
    traverse (makeConference chrisAccountK pastTime futureTime)
      ["Chris Conf 9000", "Chris's Other Conf"]
  chrisConferenceClosed <-
    makeConference chrisAccountK pastTime pastTime "Chris's Best Conf"
  let chrisConferencesF =
        chrisConferencesOpen <> [chrisConferenceClosed]

  alexeyConferencesF <-
    traverse (makeConference alexeyAccountK pastTime futureTime)
      ["Alexey Conf 9000", "Alexey's Other Conf", "Alexeys's Best Conf" ]

  let chrisFirstConf = unsafeIdx chrisConferencesF 0
      chrisFirstConfK = entityKey chrisFirstConf
      chrisSecondConf = unsafeIdx chrisConferencesF 1
      chrisSecondConfK = entityKey chrisSecondConf
      shortTalkDur = TalkDuration (Minutes 15)
      defaultTalkDur = TalkDuration (Minutes 60)
      longTalkDur = TalkDuration (Minutes 120)

  firstConfAbstractTypesF <-
    traverse (uncurry $ makeAbstractType chrisFirstConfK)
    [ ( defaultTalkDur, "Goldilocks" )
    , ( shortTalkDur, "Crisp" )
    , ( longTalkDur, "The Thing" )
    ]
  secondConfAbstractTypesF <-
    traverse (uncurry $ makeAbstractType chrisSecondConfK)
    [ ( defaultTalkDur, "Spam!" )
    ]
  let allAbstractTypesF =
        firstConfAbstractTypesF <> secondConfAbstractTypesF

  let goldilocksAbstractType = unsafeIdx allAbstractTypesF 0
      goldilocksAbstractTypeK = entityKey goldilocksAbstractType
      crispAbstractType = unsafeIdx allAbstractTypesF 1
      crispAbstractTypeK = entityKey crispAbstractType
      theThingAbstractType = unsafeIdx allAbstractTypesF 2
      theThingAbstractTypeK = entityKey theThingAbstractType
      secondConfSpamAbstractType = unsafeIdx secondConfAbstractTypesF 0
      secondConfSpamAbstractTypeK = entityKey secondConfSpamAbstractType

  chrisConfAbstracts <-
    traverse (uncurry $ makeAbstract waddlesUserK)
      [ ( theThingAbstractTypeK
        , "zygohistomorphic prepromorphisms and their malcontents"
        )
      , ( crispAbstractTypeK
        , "crispy potato chips and their manifold destiny"
        )
      , ( goldilocksAbstractTypeK
        , "Bananas, Lenses and Barbreh Strysend"
        )
      ]

  secondConfSpamAbstracts <-
    replicateM 750 (makeAbstract waddlesUserK secondConfSpamAbstractTypeK "Spam spam spam!")

  secondConfUniqueAbstract <-
    makeAbstract waddlesUserK secondConfSpamAbstractTypeK "Unique"

  let secondConfBlockedAbstract' =
        makeAbstract' waddlesUserK secondConfSpamAbstractTypeK "This was blocked"
  secondConfBlockedAbstract <-
    insertEntity (secondConfBlockedAbstract' { abstractBlocked = True } )

  let allAbstractsF =
           chrisConfAbstracts
        <> [ secondConfUniqueAbstract
           , secondConfBlockedAbstract
           ]
        <> secondConfSpamAbstracts

  let allConferencesF = chrisConferencesF ++ alexeyConferencesF
      userF = UserFixtures {..}
      ownerF = OwnerFixtures {..}
      accountF = AccountFixtures {..}
      conferenceF = ConferenceFixtures {..}
      abstractTypeF = AbstractTypeFixtures {..}
      abstractF = AbstractFixtures {..}
  return Fixtures {..}


getTables :: DB [Text]
getTables = do
  tables <- rawSql [st|
                      SELECT table_name
                      FROM information_schema.tables
                      WHERE table_schema = 'public'
                      AND table_type='BASE TABLE';
                   |] []
  return $ map unSingle tables

truncateAllTables :: DB ()
truncateAllTables = do
  tables <- getTables
  sqlBackend <- ask
  let escapedTables :: [Text]
      escapedTables =
        map (connEscapeName sqlBackend . DBName) tables
      query =
        [st|TRUNCATE TABLE #{intercalate ", " escapedTables} RESTART IDENTITY CASCADE|]
  case escapedTables of
    [] ->
      error "List of tables is empty, something has gone wrong!"
    _ -> rawExecute query []

runMigrationsUnsafe :: DB ()
runMigrationsUnsafe = runMigrationUnsafe migrateAll

wipeAndReinstallFixtures :: DB ()
wipeAndReinstallFixtures = do
  truncateAllTables
  void $ insertFixtures

wipeAndMigrateDatabase :: DB ()
wipeAndMigrateDatabase = do
  truncateAllTables
  runMigrationsUnsafe
  void $ insertFixtures

freshDatabase :: DB ()
freshDatabase = do
  runMigrationsUnsafe
  void $ insertFixtures
