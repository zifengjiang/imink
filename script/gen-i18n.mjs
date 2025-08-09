/**
 * 国际化数据生成器 (gen-i18n.mjs)
 * 
 * 这个脚本用于生成《喷射战士3》游戏的多语言翻译文件。
 * 
 * 功能：
 * 1. 从官方数据源获取最新的游戏数据版本和翻译
 * 2. 生成JSON格式的翻译文件（用于React Native应用）
 * 3. 生成iOS格式的本地化文件（.strings文件）
 * 
 * 支持的语言：
 * - 英文 (en)
 * - 日文 (ja) 
 * - 简体中文 (zh-Hans)
 * - 繁体中文 (zh-Hant)
 * - 德文 (de)
 * - 西班牙文 (es)
 * - 法文 (fr)
 * - 意大利文 (it)
 * - 韩文 (ko)
 * - 荷兰文 (nl)
 * - 俄文 (ru)
 * 
 * 生成的文件：
 * - i18n/en.json, i18n/ja.json, i18n/zh-Hans.json, i18n/zh-Hant.json
 * - Shared/en.lproj/SplatNet.strings, Shared/en.lproj/Localizable.strings
 * - Shared/ja.lproj/SplatNet.strings, Shared/ja.lproj/Localizable.strings
 * - Shared/zh-Hans.lproj/SplatNet.strings, Shared/zh-Hans.lproj/Localizable.strings
 * - Shared/zh-Hant.lproj/SplatNet.strings, Shared/zh-Hant.lproj/Localizable.strings
 * - Shared/de.lproj/SplatNet.strings, Shared/de.lproj/Localizable.strings
 * - Shared/es.lproj/SplatNet.strings, Shared/es.lproj/Localizable.strings
 * - Shared/fr.lproj/SplatNet.strings, Shared/fr.lproj/Localizable.strings
 * - Shared/it.lproj/SplatNet.strings, Shared/it.lproj/Localizable.strings
 * - Shared/ko.lproj/SplatNet.strings, Shared/ko.lproj/Localizable.strings
 * - Shared/nl.lproj/SplatNet.strings, Shared/nl.lproj/Localizable.strings
 * - Shared/ru.lproj/SplatNet.strings, Shared/ru.lproj/Localizable.strings
 * 
 * 使用方法：
 * node tools/gen-i18n.mjs
 */

import { Buffer } from "buffer";
import { createHash } from "crypto";
import { createWriteStream, mkdirSync } from "fs";
import { dirname } from "path";

const writeOut = (path, obj) => {
  const file = createWriteStream(path, "utf-8");
  file.write(JSON.stringify(obj, undefined, 2) + "\n");
};

// 新增：生成iOS .strings文件格式的函数
const writeIOSStrings = (path, obj) => {
  // 确保目录存在
  const dir = dirname(path);
  try {
    mkdirSync(dir, { recursive: true });
  } catch (error) {
    // 目录可能已经存在，忽略错误
  }

  const file = createWriteStream(path, "utf-8");

  // 写入iOS .strings文件格式
  for (const [key, value] of Object.entries(obj)) {
    // 转义双引号和反斜杠
    const escapedValue = value.replace(/"/g, '\\"').replace(/\\/g, '\\\\');
    file.write(`"${key}" = "${escapedValue}";\n`);
  }

  file.end();
};

// 新增：生成iOS本地化文件的函数
const generateIOSLocalization = async (languages, localesData) => {
  const iosLanguages = [
    { code: "en", name: "en" },
    { code: "ja", name: "ja" },
    { code: "zh-Hans", name: "zh-Hans" },
    { code: "zh-Hant", name: "zh-Hant" },
    { code: "de", name: "de" },
    { code: "es", name: "es" },
    { code: "fr", name: "fr" },
    { code: "it", name: "it" },
    { code: "ko", name: "ko" },
    { code: "nl", name: "nl" },
    { code: "ru", name: "ru" }
  ];

  // 通用UI字符串映射
  const commonStringsMap = {
    en: {
      "tab_home": "Home",
      "tab_battle": "Battles",
      "tab_salmon_run": "Salmon Run",
      "tab_me": "Me",
      "setting_page_title": "Settings",
      "setting_page_done": "Done",
      "low_tide": "Low Tide",
      "normal": "Normal",
      "high_tide": "High Tide",
      "appearances_number": "Appearances",
      "boss_salmonids": "Boss Salmonids",
      "job_score": "Job Score",
      "pay_grade": "Pay Grade",
      "clear_bonus": "Clear Bonus",
      "your_points": "Your Points"
    },
    ja: {
      "tab_home": "ホーム",
      "tab_battle": "バトル",
      "tab_salmon_run": "サーモンラン",
      "tab_me": "マイページ",
      "setting_page_title": "設定",
      "setting_page_done": "完了",
      "low_tide": "干潮",
      "normal": "普通",
      "high_tide": "満潮",
      "appearances_number": "出現数",
      "boss_salmonids": "巨大サーモン",
      "job_score": "バイトスコア",
      "pay_grade": "評価等級",
      "clear_bonus": "クリアボーナス",
      "your_points": "獲得ポイント"
    },
    "zh-Hans": {
      "tab_home": "主页",
      "tab_battle": "对战",
      "tab_salmon_run": "鲑鱼跑",
      "tab_me": "我",
      "setting_page_title": "设置",
      "setting_page_done": "完成",
      "low_tide": "干潮",
      "normal": "普通",
      "high_tide": "满潮",
      "appearances_number": "出现数量",
      "boss_salmonids": "巨大鲑鱼",
      "job_score": "打工分数",
      "pay_grade": "评价等级",
      "clear_bonus": "通关奖励",
      "your_points": "获得点数"
    },
    "zh-Hant": {
      "tab_home": "主頁",
      "tab_battle": "對戰",
      "tab_salmon_run": "鮭魚跑",
      "tab_me": "我",
      "setting_page_title": "設置",
      "setting_page_done": "完成",
      "low_tide": "乾潮",
      "normal": "普通",
      "high_tide": "滿潮",
      "appearances_number": "出現數量",
      "boss_salmonids": "巨大鮭魚",
      "job_score": "打工分數",
      "pay_grade": "評價等級",
      "clear_bonus": "通關獎勵",
      "your_points": "獲得點數"
    },
    de: {
      "tab_home": "Startseite",
      "tab_battle": "Kämpfe",
      "tab_salmon_run": "Salmoniden-Run",
      "tab_me": "Ich",
      "setting_page_title": "Einstellungen",
      "setting_page_done": "Fertig",
      "low_tide": "Niedrigwasser",
      "normal": "Normal",
      "high_tide": "Hochwasser",
      "appearances_number": "Erscheinungen",
      "boss_salmonids": "Boss-Salmoniden",
      "job_score": "Job-Punktzahl",
      "pay_grade": "Bezahlungsgrad",
      "clear_bonus": "Clear-Bonus",
      "your_points": "Deine Punkte"
    },
    es: {
      "tab_home": "Inicio",
      "tab_battle": "Batallas",
      "tab_salmon_run": "Pesca del Salmón",
      "tab_me": "Yo",
      "setting_page_title": "Configuración",
      "setting_page_done": "Hecho",
      "low_tide": "Marea Baja",
      "normal": "Normal",
      "high_tide": "Marea Alta",
      "appearances_number": "Apariciones",
      "boss_salmonids": "Salmonidos Jefe",
      "job_score": "Puntuación del Trabajo",
      "pay_grade": "Grado de Pago",
      "clear_bonus": "Bonificación de Limpieza",
      "your_points": "Tus Puntos"
    },
    fr: {
      "tab_home": "Accueil",
      "tab_battle": "Batailles",
      "tab_salmon_run": "Mission Saumon",
      "tab_me": "Moi",
      "setting_page_title": "Paramètres",
      "setting_page_done": "Terminé",
      "low_tide": "Marée Basse",
      "normal": "Normal",
      "high_tide": "Marée Haute",
      "appearances_number": "Apparitions",
      "boss_salmonids": "Saumonides Boss",
      "job_score": "Score du Travail",
      "pay_grade": "Niveau de Rémunération",
      "clear_bonus": "Bonus de Nettoyage",
      "your_points": "Tes Points"
    },
    it: {
      "tab_home": "Home",
      "tab_battle": "Battaglie",
      "tab_salmon_run": "Pesca del Salmone",
      "tab_me": "Io",
      "setting_page_title": "Impostazioni",
      "setting_page_done": "Fatto",
      "low_tide": "Marea Bassa",
      "normal": "Normale",
      "high_tide": "Marea Alta",
      "appearances_number": "Apparizioni",
      "boss_salmonids": "Salmonidi Boss",
      "job_score": "Punteggio Lavoro",
      "pay_grade": "Grado di Pagamento",
      "clear_bonus": "Bonus di Pulizia",
      "your_points": "I Tuoi Punti"
    },
    ko: {
      "tab_home": "홈",
      "tab_battle": "배틀",
      "tab_salmon_run": "연어 런",
      "tab_me": "나",
      "setting_page_title": "설정",
      "setting_page_done": "완료",
      "low_tide": "간조",
      "normal": "보통",
      "high_tide": "만조",
      "appearances_number": "출현 수",
      "boss_salmonids": "보스 연어",
      "job_score": "알바 점수",
      "pay_grade": "급여 등급",
      "clear_bonus": "클리어 보너스",
      "your_points": "획득 포인트"
    },
    nl: {
      "tab_home": "Home",
      "tab_battle": "Gevechten",
      "tab_salmon_run": "Zalmrun",
      "tab_me": "Ik",
      "setting_page_title": "Instellingen",
      "setting_page_done": "Klaar",
      "low_tide": "Laagwater",
      "normal": "Normaal",
      "high_tide": "Hoogwater",
      "appearances_number": "Verschijningen",
      "boss_salmonids": "Baas-Zalmachtigen",
      "job_score": "Werk Score",
      "pay_grade": "Betaalgraad",
      "clear_bonus": "Clear Bonus",
      "your_points": "Jouw Punten"
    },
    ru: {
      "tab_home": "Главная",
      "tab_battle": "Битвы",
      "tab_salmon_run": "Лососевый Забег",
      "tab_me": "Я",
      "setting_page_title": "Настройки",
      "setting_page_done": "Готово",
      "low_tide": "Отлив",
      "normal": "Обычный",
      "high_tide": "Прилив",
      "appearances_number": "Появления",
      "boss_salmonids": "Босс-Лососи",
      "job_score": "Оценка Работы",
      "pay_grade": "Уровень Оплаты",
      "clear_bonus": "Бонус Очистки",
      "your_points": "Твои Очки"
    }
  };

  for (let i = 0; i < iosLanguages.length; i++) {
    const lang = iosLanguages[i];
    const localeData = localesData[i];

    try {
      // 生成 SplatNet.strings 文件
      const splatNetPath = `Shared/${lang.name}.lproj/SplatNet.strings`;
      writeIOSStrings(splatNetPath, localeData);
      console.log(`Generated ${splatNetPath}`);

      // 生成 Localizable.strings 文件
      const localizablePath = `Shared/${lang.name}.lproj/Localizable.strings`;
      const commonStrings = commonStringsMap[lang.code] || commonStringsMap.en;
      writeIOSStrings(localizablePath, commonStrings);
      console.log(`Generated ${localizablePath}`);
    } catch (error) {
      console.error(`Error generating iOS localization for ${lang.name}:`, error);
    }
  }
};

const getVersion = async () => {
  const res = await fetch("https://raw.githubusercontent.com/Leanny/splat3/main/data/mush/latest");
  return await res.text();
};

const getLanguage = async (language) => {
  const res = fetch(
    `https://raw.githubusercontent.com/Leanny/splat3/main/data/language/${language}_unicode.json`,
  );
  const json = (await res).json();
  return json;
};
const getModeLocales = (languages) => {
  const map = {
    Regular: 1,
    Bankara: 2,
    XMatch: 3,
    League: 4,
    Private: 5,
    FestRegular: 6,
    FestChallenge: 7,
    FestTriColor: 8,
    BankaraOpen: 51,
  };
  const maps = [];
  for (let i = 0; i < languages.length; i++) {
    maps.push({});
  }
  for (let i = 0; i < languages.length; i++) {
    for (const mode of Object.keys(languages[i]["CommonMsg/MatchMode"])) {
      if (map[mode] !== undefined) {
        const id = Buffer.from(`VsMode-${map[mode]}`).toString("base64");
        const name = languages[i]["CommonMsg/MatchMode"][mode]
          .replace(/\[.*?\]/g, "")
          .replace("（", " (")
          .replace("）", ")");
        maps[i][id] = name;
      }
    }
  }
  return maps;
};
const genRuleLocales = (languages) => {
  const map = {
    Pnt: 0,
    Var: 1,
    Vlf: 2,
    Vgl: 3,
    Vcl: 4,
    Tcl: 5,
  };
  const maps = [];
  for (let i = 0; i < languages.length; i++) {
    maps.push({});
  }
  for (let i = 0; i < languages.length; i++) {
    for (const rule of Object.keys(languages[i]["CommonMsg/VS/VSRuleName"])) {
      if (map[rule] !== undefined) {
        const id = Buffer.from(`VsRule-${map[rule]}`).toString("base64");
        const name = languages[i]["CommonMsg/VS/VSRuleName"][rule];
        maps[i][id] = name;
      }
    }
  }
  return maps;
};
const getChallengeLocales = async (version, languages) => {
  const res = await fetch(
    `https://raw.githubusercontent.com/Leanny/splat3/main/data/mush/${version}/LeagueTypeInfo.json`,
  );
  const json = await res.json();
  const maps = [];
  for (let i = 0; i < languages.length; i++) {
    maps.push({});
  }
  for (const challenge of json) {
    const id = Buffer.from(`LeagueMatchEvent-${challenge["__RowId"]}`).toString("base64");
    for (let i = 0; i < languages.length; i++) {
      const name =
        languages[i]["CommonMsg/Manual/ManualEventMatch"][
        `EventMatch_${challenge["__RowId"]}_Title`
        ];
      maps[i][id] = name;
    }
  }
  return maps;
};
const getStageLocales = async (version, languages) => {
  const res = await fetch(
    `https://raw.githubusercontent.com/Leanny/splat3/main/data/mush/${version}/VersusSceneInfo.json`,
  );
  const json = await res.json();
  const maps = [];
  for (let i = 0; i < languages.length; i++) {
    maps.push({});
  }
  for (const stage of json) {
    const id = Buffer.from(`VsStage-${stage["Id"]}`).toString("base64");
    for (let i = 0; i < languages.length; i++) {
      const name =
        languages[i]["CommonMsg/VS/VSStageName"][stage["__RowId"].match(/Vss_([a-zA-Z]+)/)[1]];
      maps[i][id] = name;
    }
  }
  return maps;
};
const getCoopStageLocales = async (version, languages) => {
  const res = await fetch(
    `https://raw.githubusercontent.com/Leanny/splat3/main/data/mush/${version}/CoopSceneInfo.json`,
  );
  const json = await res.json();
  const maps = [];
  for (let i = 0; i < languages.length; i++) {
    maps.push({});
  }
  for (const stage of json) {
    const id = Buffer.from(`CoopStage-${stage["Id"]}`).toString("base64");
    for (let i = 0; i < languages.length; i++) {
      const name =
        languages[i]["CommonMsg/Coop/CoopStageName"][stage["__RowId"].match(/Cop_([a-zA-Z]+)/)[1]];
      maps[i][id] = name;
    }
  }
  return maps;
};
const getWeaponLocales = async (version, languages) => {
  const res = await fetch(
    `https://raw.githubusercontent.com/Leanny/splat3/main/data/mush/${version}/WeaponInfoMain.json`,
  );
  const json = await res.json();
  const maps = [];
  for (let i = 0; i < languages.length; i++) {
    maps.push({});
  }
  for (const weapon of json) {
    if (weapon["Type"] === "Versus" || (weapon["Type"] === "Coop" && weapon["IsCoopRare"])) {
      const id = Buffer.from(`Weapon-${weapon["Id"]}`).toString("base64");
      for (let i = 0; i < languages.length; i++) {
        const name = languages[i]["CommonMsg/Weapon/WeaponName_Main"][weapon["__RowId"]];
        maps[i][id] = name;
      }
    }
  }
  return maps;
};
const getCoopSpecialWeaponLocales = async (version, languages) => {
  const res = await fetch(
    `https://raw.githubusercontent.com/Leanny/splat3/main/data/mush/${version}/WeaponInfoSpecial.json`,
  );
  const json = await res.json();
  const maps = [];
  for (let i = 0; i < languages.length; i++) {
    maps.push({});
  }
  for (const specialWeapon of json) {
    if (specialWeapon["Type"] === "Coop") {
      const id = Buffer.from(`SpecialWeapon-${specialWeapon["Id"]}`).toString("base64");
      for (let i = 0; i < languages.length; i++) {
        const name = languages[i]["CommonMsg/Weapon/WeaponName_Special"][specialWeapon["__RowId"]];
        maps[i][id] = name;
      }
    }
  }
  return maps;
};
const getTitleLocales = (languages) => {
  // HACK: only support languages without declension.
  const maps = [];
  for (let i = 0; i < languages.length; i++) {
    maps.push({});
  }
  for (let i = 0; i < languages.length; i++) {
    for (const adjective of Object.keys(languages[i]["CommonMsg/Byname/BynameAdjective"])) {
      const id = `TitleAdjective-${adjective}`;
      maps[i][id] = languages[i]["CommonMsg/Byname/BynameAdjective"][adjective].replaceAll(
        /\[.+?\]/g,
        "",
      );
    }
    for (const subject of Object.keys(languages[i]["CommonMsg/Byname/BynameSubject"])) {
      if (subject.endsWith("_0")) {
        const neutralSubject = subject.replace("_0", "");
        const altSubject = `${neutralSubject}_1`;
        const neutralId = `TitleSubject-${neutralSubject}`;
        const id = `TitleSubject-${subject}`;
        const altId = `TitleSubject-${altSubject}`;
        if (languages[i]["CommonMsg/Byname/BynameSubject"][altSubject].includes("group=0001")) {
          maps[i][neutralId] = languages[i]["CommonMsg/Byname/BynameSubject"][subject].replaceAll(
            /\[.+?\]/g,
            "",
          );
          maps[i][id] = languages[i]["CommonMsg/Byname/BynameSubject"][subject].replaceAll(
            /\[.+?\]/g,
            "",
          );
          maps[i][altId] = languages[i]["CommonMsg/Byname/BynameSubject"][subject].replaceAll(
            /\[.+?\]/g,
            "",
          );
        } else {
          maps[i][neutralId] = `${languages[i]["CommonMsg/Byname/BynameSubject"][
            subject
          ].replaceAll(/\[.+?\]/g, "")}/${languages[i]["CommonMsg/Byname/BynameSubject"][
            altSubject
          ].replaceAll(/\[.+?\]/g, "")}`;
          maps[i][id] = languages[i]["CommonMsg/Byname/BynameSubject"][subject].replaceAll(
            /\[.+?\]/g,
            "",
          );
          maps[i][altId] = languages[i]["CommonMsg/Byname/BynameSubject"][altSubject].replaceAll(
            /\[.+?\]/g,
            "",
          );
        }
      }
    }
  }
  return maps;
};
const getBrandLocales = (languages) => {
  const maps = [];
  for (let i = 0; i < languages.length; i++) {
    maps.push({});
  }
  for (let i = 0; i < languages.length; i++) {
    for (const brand of Object.keys(languages[i]["CommonMsg/Gear/GearBrandName"])) {
      const id = Buffer.from(`Brand-${Number.parseInt(brand.replace("B", ""))}`).toString("base64");
      const name = languages[i]["CommonMsg/Gear/GearBrandName"][brand];
      maps[i][id] = name;
    }
  }
  return maps;
};
const getHeadgearLocales = async (version, languages) => {
  const res = await fetch(
    `https://raw.githubusercontent.com/Leanny/splat3/main/data/mush/${version}/GearInfoHead.json`,
  );
  const json = await res.json();
  const maps = [];
  for (let i = 0; i < languages.length; i++) {
    maps.push({});
  }
  for (const head of json) {
    const image = createHash("sha256").update(head["__RowId"]).digest("hex");
    for (let i = 0; i < languages.length; i++) {
      const name =
        languages[i]["CommonMsg/Gear/GearName_Head"][head["__RowId"].replace("Hed_", "")];
      maps[i][image] = name;
    }
  }
  return maps;
};
const getClothesLocales = async (version, languages) => {
  const res = await fetch(
    `https://raw.githubusercontent.com/Leanny/splat3/main/data/mush/${version}/GearInfoClothes.json`,
  );
  const json = await res.json();
  const maps = [];
  for (let i = 0; i < languages.length; i++) {
    maps.push({});
  }
  for (const cloth of json) {
    const image = createHash("sha256").update(cloth["__RowId"]).digest("hex");
    for (let i = 0; i < languages.length; i++) {
      const name =
        languages[i]["CommonMsg/Gear/GearName_Clothes"][cloth["__RowId"].replace("Clt_", "")];
      maps[i][image] = name;
    }
  }
  return maps;
};
const getShoesLocales = async (version, languages) => {
  const res = await fetch(
    `https://raw.githubusercontent.com/Leanny/splat3/main/data/mush/${version}/GearInfoShoes.json`,
  );
  const json = await res.json();
  const maps = [];
  for (let i = 0; i < languages.length; i++) {
    maps.push({});
  }
  for (const shoe of json) {
    const image = createHash("sha256").update(shoe["__RowId"]).digest("hex");
    for (let i = 0; i < languages.length; i++) {
      const name =
        languages[i]["CommonMsg/Gear/GearName_Shoes"][shoe["__RowId"].replace("Shs_", "")];
      maps[i][image] = name;
    }
  }
  return maps;
};
const getAwardLocales = (languages) => {
  const maps = [];
  for (let i = 0; i < languages.length; i++) {
    maps.push({});
  }
  for (let i = 0; i < languages.length; i++) {
    for (const award of Object.keys(languages[i]["CommonMsg/VS/VSAwardName"])) {
      if (!award.startsWith("Ref_")) {
        const id = `Award-${award}`;
        const name = languages[i]["CommonMsg/VS/VSAwardName"][award];
        maps[i][id] = name;
      }
    }
  }
  return maps;
};
const getGradeLocales = (languages) => {
  const maps = [];
  for (let i = 0; i < languages.length; i++) {
    maps.push({});
  }
  for (let i = 0; i < languages.length; i++) {
    for (const grade of Object.keys(languages[i]["CommonMsg/Coop/CoopGrade"])) {
      if (grade.match(/Grade_\d\d/)) {
        const id = Buffer.from(
          `CoopGrade-${Number.parseInt(grade.replace("Grade_", ""))}`,
        ).toString("base64");
        const name = languages[i]["CommonMsg/Coop/CoopGrade"][grade];
        maps[i][id] = name;
      }
    }
  }
  return maps;
};
const getEventLocales = async (version, languages) => {
  const map = {
    EventRush: 1,
    EventGeyser: 2,
    EventDozer: 3,
    EventHakobiya: 4,
    EventFog: 5,
    EventMissile: 6,
    EventRelay: 7,
    EventTamaire: 8,
  };
  const res = await fetch(
    `https://raw.githubusercontent.com/Leanny/splat3/main/data/parameter/${version}/misc/spl__CoopLevelsConfig.spl__CoopLevelsConfig.json`,
  );
  const json = await res.json();
  const maps = [];
  for (let i = 0; i < languages.length; i++) {
    maps.push({});
  }
  for (const event of Object.keys(json["Levels"][0])) {
    if (map[event]) {
      const id = Buffer.from(`CoopEventWave-${map[event]}`).toString("base64");
      for (let i = 0; i < languages.length; i++) {
        const name = languages[i]["CommonMsg/Glossary"][`CoopEvent_${event.replace("Event", "")}`];
        maps[i][id] = name;
      }
    }
  }
  return maps;
};
const getSalmonidLocales = async (version, languages) => {
  const map = {
    SakelienBomber: 4,
    SakelienCupTwins: 5,
    SakelienShield: 6,
    SakelienSnake: 7,
    SakelienTower: 8,
    Sakediver: 9,
    Sakerocket: 10,
    SakePillar: 11,
    SakeDolphin: 12,
    SakeArtillery: 13,
    SakeSaucer: 14,
    SakelienGolden: 15,
    Sakedozer: 17,
    SakeBigMouth: 20,
    SakelienGiant: 23,
    SakeRope: 24,
    SakeJaw: 25,
  };
  const res = await fetch(
    `https://raw.githubusercontent.com/Leanny/splat3/main/data/mush/${version}/CoopEnemyInfo.json`,
  );
  const json = await res.json();
  const maps = [];
  for (let i = 0; i < languages.length; i++) {
    maps.push({});
  }
  for (const salmonid of json) {
    if (map[salmonid["Type"]]) {
      const id = Buffer.from(`CoopEnemy-${map[salmonid["Type"]]}`).toString("base64");
      for (let i = 0; i < languages.length; i++) {
        const name = languages[i]["CommonMsg/Coop/CoopEnemy"][salmonid["Type"]];
        maps[i][id] = name;
      }
    }
  }
  return maps;
};
const getWorkSuitLocales = async (version, languages) => {
  const res = await fetch(
    `https://raw.githubusercontent.com/Leanny/splat3/main/data/mush/${version}/CoopSkinInfo.json`,
  );
  const json = await res.json();
  const maps = [];
  for (let i = 0; i < languages.length; i++) {
    maps.push({});
  }
  for (const workSuit of json) {
    const id = Buffer.from(`CoopUniform-${workSuit["Id"]}`).toString("base64");
    for (let i = 0; i < languages.length; i++) {
      const name = languages[i]["CommonMsg/Coop/CoopSkinName"][workSuit["__RowId"]];
      maps[i][id] = name;
    }
  }
  return maps;
};

const version = await getVersion();
const languages = await Promise.all([
  getLanguage("USen"),
  getLanguage("JPja"),
  getLanguage("CNzh"),
  getLanguage("TWzh"),
  getLanguage("EUde"),
  getLanguage("EUes"),
  getLanguage("EUfr"),
  getLanguage("EUit"),
  getLanguage("KRko"),
  getLanguage("EUnl"),
  getLanguage("EUru"),
]);
const [
  modeLocales,
  ruleLocales,
  challengeLocales,
  stageLocales,
  coopStageLocales,
  weaponLocales,
  coopSpecialWeaponLocales,
  titleLocales,
  brandLocales,
  headgearLocales,
  clothesLocales,
  shoesLocales,
  awardLocales,
  gradeLocales,
  eventLocales,
  salmonidLocales,
  workSuitLocales,
] = await Promise.all([
  getModeLocales(languages),
  genRuleLocales(languages),
  getChallengeLocales(version, languages),
  getStageLocales(version, languages),
  getCoopStageLocales(version, languages),
  getWeaponLocales(version, languages),
  getCoopSpecialWeaponLocales(version, languages),
  getTitleLocales(languages),
  getBrandLocales(languages),
  getHeadgearLocales(version, languages),
  getClothesLocales(version, languages),
  getShoesLocales(version, languages),
  getGradeLocales(languages),
  getAwardLocales(languages),
  getEventLocales(version, languages),
  getSalmonidLocales(version, languages),
  getWorkSuitLocales(version, languages),
]);

// 生成iOS本地化文件
await generateIOSLocalization(languages, [
  {
    ...modeLocales[0],
    ...ruleLocales[0],
    ...challengeLocales[0],
    ...stageLocales[0],
    ...coopStageLocales[0],
    ...weaponLocales[0],
    ...coopSpecialWeaponLocales[0],
    ...titleLocales[0],
    ...brandLocales[0],
    ...headgearLocales[0],
    ...clothesLocales[0],
    ...shoesLocales[0],
    ...awardLocales[0],
    ...gradeLocales[0],
    ...eventLocales[0],
    ...salmonidLocales[0],
    ...workSuitLocales[0],
  },
  {
    ...modeLocales[1],
    ...ruleLocales[1],
    ...challengeLocales[1],
    ...stageLocales[1],
    ...coopStageLocales[1],
    ...weaponLocales[1],
    ...coopSpecialWeaponLocales[1],
    ...titleLocales[1],
    ...brandLocales[1],
    ...headgearLocales[1],
    ...clothesLocales[1],
    ...shoesLocales[1],
    ...awardLocales[1],
    ...gradeLocales[1],
    ...eventLocales[1],
    ...salmonidLocales[1],
    ...workSuitLocales[1],
  },
  {
    ...modeLocales[2],
    ...ruleLocales[2],
    ...challengeLocales[2],
    ...stageLocales[2],
    ...coopStageLocales[2],
    ...weaponLocales[2],
    ...coopSpecialWeaponLocales[2],
    ...titleLocales[2],
    ...brandLocales[2],
    ...headgearLocales[2],
    ...clothesLocales[2],
    ...shoesLocales[2],
    ...awardLocales[2],
    ...gradeLocales[2],
    ...eventLocales[2],
    ...salmonidLocales[2],
    ...workSuitLocales[2],
  },
  {
    ...modeLocales[3],
    ...ruleLocales[3],
    ...challengeLocales[3],
    ...stageLocales[3],
    ...coopStageLocales[3],
    ...weaponLocales[3],
    ...coopSpecialWeaponLocales[3],
    ...titleLocales[3],
    ...brandLocales[3],
    ...headgearLocales[3],
    ...clothesLocales[3],
    ...shoesLocales[3],
    ...awardLocales[3],
    ...gradeLocales[3],
    ...eventLocales[3],
    ...salmonidLocales[3],
    ...workSuitLocales[3],
  },
  {
    ...modeLocales[4],
    ...ruleLocales[4],
    ...challengeLocales[4],
    ...stageLocales[4],
    ...coopStageLocales[4],
    ...weaponLocales[4],
    ...coopSpecialWeaponLocales[4],
    ...titleLocales[4],
    ...brandLocales[4],
    ...headgearLocales[4],
    ...clothesLocales[4],
    ...shoesLocales[4],
    ...awardLocales[4],
    ...gradeLocales[4],
    ...eventLocales[4],
    ...salmonidLocales[4],
    ...workSuitLocales[4],
  },
  {
    ...modeLocales[5],
    ...ruleLocales[5],
    ...challengeLocales[5],
    ...stageLocales[5],
    ...coopStageLocales[5],
    ...weaponLocales[5],
    ...coopSpecialWeaponLocales[5],
    ...titleLocales[5],
    ...brandLocales[5],
    ...headgearLocales[5],
    ...clothesLocales[5],
    ...shoesLocales[5],
    ...awardLocales[5],
    ...gradeLocales[5],
    ...eventLocales[5],
    ...salmonidLocales[5],
    ...workSuitLocales[5],
  },
  {
    ...modeLocales[6],
    ...ruleLocales[6],
    ...challengeLocales[6],
    ...stageLocales[6],
    ...coopStageLocales[6],
    ...weaponLocales[6],
    ...coopSpecialWeaponLocales[6],
    ...titleLocales[6],
    ...brandLocales[6],
    ...headgearLocales[6],
    ...clothesLocales[6],
    ...shoesLocales[6],
    ...awardLocales[6],
    ...gradeLocales[6],
    ...eventLocales[6],
    ...salmonidLocales[6],
    ...workSuitLocales[6],
  },
  {
    ...modeLocales[7],
    ...ruleLocales[7],
    ...challengeLocales[7],
    ...stageLocales[7],
    ...coopStageLocales[7],
    ...weaponLocales[7],
    ...coopSpecialWeaponLocales[7],
    ...titleLocales[7],
    ...brandLocales[7],
    ...headgearLocales[7],
    ...clothesLocales[7],
    ...shoesLocales[7],
    ...awardLocales[7],
    ...gradeLocales[7],
    ...eventLocales[7],
    ...salmonidLocales[7],
    ...workSuitLocales[7],
  },
  {
    ...modeLocales[8],
    ...ruleLocales[8],
    ...challengeLocales[8],
    ...stageLocales[8],
    ...coopStageLocales[8],
    ...weaponLocales[8],
    ...coopSpecialWeaponLocales[8],
    ...titleLocales[8],
    ...brandLocales[8],
    ...headgearLocales[8],
    ...clothesLocales[8],
    ...shoesLocales[8],
    ...awardLocales[8],
    ...gradeLocales[8],
    ...eventLocales[8],
    ...salmonidLocales[8],
    ...workSuitLocales[8],
  },
  {
    ...modeLocales[9],
    ...ruleLocales[9],
    ...challengeLocales[9],
    ...stageLocales[9],
    ...coopStageLocales[9],
    ...weaponLocales[9],
    ...coopSpecialWeaponLocales[9],
    ...titleLocales[9],
    ...brandLocales[9],
    ...headgearLocales[9],
    ...clothesLocales[9],
    ...shoesLocales[9],
    ...awardLocales[9],
    ...gradeLocales[9],
    ...eventLocales[9],
    ...salmonidLocales[9],
    ...workSuitLocales[9],
  },
  {
    ...modeLocales[10],
    ...ruleLocales[10],
    ...challengeLocales[10],
    ...stageLocales[10],
    ...coopStageLocales[10],
    ...weaponLocales[10],
    ...coopSpecialWeaponLocales[10],
    ...titleLocales[10],
    ...brandLocales[10],
    ...headgearLocales[10],
    ...clothesLocales[10],
    ...shoesLocales[10],
    ...awardLocales[10],
    ...gradeLocales[10],
    ...eventLocales[10],
    ...salmonidLocales[10],
    ...workSuitLocales[10],
  },
  {
    ...modeLocales[11],
    ...ruleLocales[11],
    ...challengeLocales[11],
    ...stageLocales[11],
    ...coopStageLocales[11],
    ...weaponLocales[11],
    ...coopSpecialWeaponLocales[11],
    ...titleLocales[11],
    ...brandLocales[11],
    ...headgearLocales[11],
    ...clothesLocales[11],
    ...shoesLocales[11],
    ...awardLocales[11],
    ...gradeLocales[11],
    ...eventLocales[11],
    ...salmonidLocales[11],
    ...workSuitLocales[11],
  },
]);
