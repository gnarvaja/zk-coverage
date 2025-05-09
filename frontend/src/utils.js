import { unzip } from "lodash-es";
import { STORM_CONFIG, PRICE_CONFIG } from "./config/config";

function floatToWad(floatValue) {
  return BigInt(Math.round(floatValue * 10000)) * 10n ** 14n;
}

export function wadToFloat(lossProbAsWad) {
  return parseInt(lossProbAsWad / 10n ** 12n) / 1e8;
}

export function formatLossProb(lossProbAsWad) {
  return (wadToFloat(lossProbAsWad) * 100).toFixed(2) + " %";
}

export function computePremium(insuredAmount, lossProb, durationInDays) {
  const rmParams = {
    moc: 1,
    jrCollRatio: 0.25,
    collRatio: 0.9,
    ensuroPpFee: 0.1,
    ensuroCocFee: 0.1,
    srRoc: 0.1,
    jrRoc: 0.3,
  };
  const purePremium = wadToFloat(lossProb) * rmParams.moc * insuredAmount;
  const jrScr = Math.max(0, insuredAmount * rmParams.jrCollRatio - purePremium);
  const srScr = Math.max(
    0,
    insuredAmount * rmParams.collRatio - jrScr - purePremium,
  );
  const jrCoc = jrScr * rmParams.jrRoc * (durationInDays / 365);
  const srCoc = srScr * rmParams.srRoc * (durationInDays / 365);
  const ensuroCocFee = (jrCoc + srCoc) * rmParams.ensuroCocFee;
  const ensuroPpFee = purePremium * rmParams.ensuroPpFee;
  return purePremium + jrCoc + srCoc + ensuroPpFee + ensuroCocFee;
}

export const loadStormAreas = async () => {
  try {
    const response = await fetch(
      `${STORM_CONFIG.stormsPath}/${STORM_CONFIG.defaultStorm}.json`,
    );
    if (!response.ok) {
      throw new Error("Failed to load storm data");
    }
    const stormData = await response.json();

    //const affected = stormData.areas || [];
    const affected = [];
    const severity = [];
    stormData.areas.forEach((area) => {
      affected.push(area[0]);
      severity.push(floatToWad(area[1]));
    });
    //const severity = affected.map(() => 1); // Default severity of 1 for each area
    //console.log("affected:", affected)
    //console.log("severity:", severity)

    return {
      affected,
      severity,
    };
  } catch (error) {
    console.error("Error loading storm areas:", error);
    return {
      affected: [],
      severity: [],
    };
  }
};

export const loadPriceAreas = async () => {
  const url = `${PRICE_CONFIG.stormsPath}/${PRICE_CONFIG.defaultStorm}.json`;
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error("Failed to load storm data");
    }
    const priceData = await response.json();

    console.log("priceData", priceData);
    const [price, riskAsFloat] = unzip(priceData.areas);
    const risk = riskAsFloat.map(floatToWad);

    return {
      price,
      risk,
    };
  } catch (error) {
    console.error(`Error loading price areas from ${url}:`, error);
    return {
      price: [],
      risk: [],
    };
  }
};
