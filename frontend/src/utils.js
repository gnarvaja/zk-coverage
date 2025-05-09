import { STORM_CONFIG, PRICE_CONFIG } from './config/config'

function floatToWad(floatValue) {
  return BigInt(Math.round(floatValue * (10 ** 18)));
}

export const loadStormAreas = async () => {
  try {
    const response = await fetch(`${STORM_CONFIG.stormsPath}/${STORM_CONFIG.defaultStorm}.json`);
    if (!response.ok) {
      throw new Error('Failed to load storm data');
    }
    const stormData = await response.json();
    
    //const affected = stormData.areas || [];
    const affected = []
    const severity = []
    stormData.areas.forEach(area =>{
        affected.push(area[0]);
        severity.push(floatToWad(area[1]))
    })
    //const severity = affected.map(() => 1); // Default severity of 1 for each area
    //console.log("affected:", affected)
    //console.log("severity:", severity)

    return {
      affected,
      severity
    };
  } catch (error) {
    console.error('Error loading storm areas:', error);
    return {
      affected: [],
      severity: []
    };
  }
};

export const loadPriceAreas = async () => {
  try {
    const response = await fetch(`${PRICE_CONFIG.stormsPath}/${PRICE_CONFIG.defaultStorm}.json`);
    if (!response.ok) {
      throw new Error('Failed to load storm data');
    }
    const priceData = await response.json();
    
    const price = []
    const risk = []
    priceData.areas.forEach(area =>{
        price.push(area[0]);
        risk.push(floatToWad(area[1]))
    })

    return {
      price,
      risk
    };
  } catch (error) {
    console.error('Error loading storm areas:', error);
    return {
      price: [],
      risk: []
    };
  }
};