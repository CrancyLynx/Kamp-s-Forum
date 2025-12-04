/**
 * ═══════════════════════════════════════════════════════════════════════════════
 * ÖSYM SINAV TAKVİMİ SCRAPING - TEST DOSYASI
 * ═══════════════════════════════════════════════════════════════════════════════
 * 
 * Bu dosya, ÖSYM scraping fonksiyonlarını test etmek için kullanılır.
 * Node.js ortamında çalıştırılabilir.
 * 
 * Kullanım: node TEST_OSYM_SCRAPING.js
 */

const axios = require('axios');
const cheerio = require('cheerio');

// Tarih parser
const parseTurkishDate = (dateString) => {
  if (!dateString || dateString.trim() === '') return null;
  const parts = dateString.split('.');
  if (parts.length !== 3) return null;
  return new Date(parts[2], parts[1] - 1, parts[0]);
};

// ÖSYM scraper
const scrapeOsymExams = async (year) => {
  try {
    const urls = {
      2025: "https://www.osym.gov.tr/TR,8709/2025-yili-sinav-takvimi.html",
      2026: "https://www.osym.gov.tr/TR,29560/2026-yili-sinav-takvimi.html",
      2027: "https://www.osym.gov.tr/TR,00000/2027-yili-sinav-takvimi.html"
    };

    const url = urls[year];
    if (!url) {
      console.warn(`❌ ${year}: URL bulunamadı`);
      return [];
    }

    console.log(`\n🔍 ${year} için veriler çekiliyor...\n   URL: ${url}`);
    
    const response = await axios.get(url, {
      timeout: 10000,
      headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' }
    });
    
    const $ = cheerio.load(response.data);
    const exams = [];
    const relevantExams = ["KPSS", "YKS", "ALES", "DGS", "TUS", "DUS", "YÖKDİL"];

    let found = 0;
    $('table tbody tr, table > tr').each((i, el) => {
      const tds = $(el).find('td');
      if (tds.length === 0) return;
      
      const examName = tds.eq(0).text().trim();
      
      if (relevantExams.some(keyword => examName.includes(keyword))) {
        const examDateStr = tds.eq(1).text().trim();
        const appStartDateStr = tds.eq(2).text().trim();
        const resultDateStr = tds.eq(3).text().trim();
        const examDate = parseTurkishDate(examDateStr);

        if (examName && examDate) {
          exams.push({
            name: examName,
            date: examDate,
            dateStr: examDateStr,
            appStart: appStartDateStr,
            result: resultDateStr
          });
          found++;
        }
      }
    });

    console.log(`✅ ${year}: ${found} sınav bulundu`);
    if (found > 0) {
      exams.forEach(exam => {
        console.log(`   📌 ${exam.name} - ${exam.dateStr} (${exam.date.toLocaleDateString('tr-TR')})`);
      });
    }
    
    return exams;
  } catch (error) {
    console.error(`❌ ${year}: ${error.message}`);
    return [];
  }
};

// MAIN TEST
async function runTests() {
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('        ÖSYM SINAV TAKVİMİ SCRAPING TEST');
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('');

  const currentYear = new Date().getFullYear();
  const yearsToTest = [currentYear, currentYear + 1];

  let totalExams = 0;
  const results = {};

  for (const year of yearsToTest) {
    const exams = await scrapeOsymExams(year);
    results[year] = exams;
    totalExams += exams.length;
  }

  console.log('\n═══════════════════════════════════════════════════════════════');
  console.log(`📊 SONUÇ: Toplam ${totalExams} sınav bulundu`);
  console.log('═══════════════════════════════════════════════════════════════\n');

  if (totalExams === 0) {
    console.log('⚠️  Hiçbir sınav bulunamadı!');
    console.log('   - ÖSYM sitesi değişmiş olabilir');
    console.log('   - URLler güncellenmiş olabilir');
    console.log('   - HTML yapısı değişmiş olabilir');
    console.log('\n   📝 Çözüm:');
    console.log('   1. ÖSYM sitesini ziyaret edin');
    console.log('   2. HTML yapısını kontrol edin');
    console.log('   3. CSS seçicileri güncelleyin');
  } else {
    console.log('✅ Scraping başarılı!');
    console.log('\n📋 Firestore verileri:');
    Object.entries(results).forEach(([year, exams]) => {
      exams.forEach(exam => {
        console.log(`   ${year}_${exam.name.replace(/\s+/g, '_').toLowerCase()}`);
      });
    });
  }
}

runTests().catch(console.error);
