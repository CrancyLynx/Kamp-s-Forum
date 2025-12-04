/**
 * ÖSYM SINAV TAKVİMİ - MOCK VERİ (Dinamik site sorunu için)
 * 
 * ÖSYM sitesi JavaScript ile dinamik içerik yüklediği için
 * static scraping yapılamıyor. Geçici çözüm olarak mock veriler
 * kullanılacak. Gerçek veri için Puppeteer veya Playwright gerekir.
 */

// Mock sınav verisi (Şu anki 2025-2026 takvimi)
const MOCK_EXAM_DATA = {
  2025: [
    { name: 'KPSS', date: '14.06.2025', appStart: '01.04.2025', result: '15.07.2025' },
    { name: 'YKS', date: '15.06.2025', appStart: '10.01.2025', result: '28.07.2025' },
    { name: 'ALES', date: '31.05.2025', appStart: '14.03.2025', result: '18.06.2025' },
    { name: 'DGS', date: '07.12.2025', appStart: '01.09.2025', result: '20.12.2025' },
    { name: 'TUS', date: '12.10.2025', appStart: '01.08.2025', result: '25.10.2025' },
    { name: 'DUS', date: '07.12.2025', appStart: '01.09.2025', result: '20.12.2025' },
    { name: 'YÖKDİL', date: '31.05.2025', appStart: '01.04.2025', result: '14.06.2025' }
  ],
  2026: [
    { name: 'KPSS', date: '20.06.2026', appStart: '01.04.2026', result: '21.07.2026' },
    { name: 'YKS', date: '21.06.2026', appStart: '10.01.2026', result: '04.08.2026' },
    { name: 'ALES', date: '30.05.2026', appStart: '14.03.2026', result: '17.06.2026' },
    { name: 'DGS', date: '05.12.2026', appStart: '01.09.2026', result: '18.12.2026' },
    { name: 'TUS', date: '10.10.2026', appStart: '01.08.2026', result: '23.10.2026' },
    { name: 'DUS', date: '05.12.2026', appStart: '01.09.2026', result: '18.12.2026' },
    { name: 'YÖKDİL', date: '30.05.2026', appStart: '01.04.2026', result: '13.06.2026' }
  ]
};

const parseTurkishDate = (dateString) => {
  if (!dateString || dateString.trim() === '') return null;
  const parts = dateString.split('.');
  if (parts.length !== 3) return null;
  return new Date(parts[2], parts[1] - 1, parts[0]);
};

const getMockExamData = (years = [2025, 2026]) => {
  const allExams = [];
  
  years.forEach(year => {
    if (MOCK_EXAM_DATA[year]) {
      MOCK_EXAM_DATA[year].forEach(exam => {
        const examDate = parseTurkishDate(exam.date);
        allExams.push({
          id: `${year}_${exam.name.replace(/\s+/g, '_').toLowerCase()}`,
          name: exam.name,
          date: examDate,
          description: `Başvuru: ${exam.appStart}, Sonuç: ${exam.result}`,
          color: 'blue',
          type: 'exam',
          source: 'OSYM',
          importance: 'high',
          year: year
        });
      });
    }
  });
  
  return allExams;
};

// Test
if (require.main === module) {
  const exams = getMockExamData([2025, 2026]);
  console.log(`\n📊 Mock Veri Test: ${exams.length} sınav\n`);
  exams.forEach(exam => {
    console.log(`✅ ${exam.name} (${exam.year}): ${exam.date.toLocaleDateString('tr-TR')}`);
  });
}

module.exports = { getMockExamData, MOCK_EXAM_DATA };
