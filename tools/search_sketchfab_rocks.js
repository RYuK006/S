// tools/search_sketchfab_rocks.js
const https = require('https');
const token = '4591437114654bf29d34a235f90acf6c';

const url = 'https://api.sketchfab.com/v3/search?type=models&q=rock+boulder+photogrammetry&downloadable=true&sort_by=-likeCount';

const req = https.get(url, { headers: { 'Authorization': `Token ${token}` } }, res => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
        try {
            const json = JSON.parse(data);
            console.log(`Total results: ${json.results.length}`);
            for (let i = 0; i < Math.min(5, json.results.length); i++) {
                const m = json.results[i];
                console.log(`[${i}] uid: ${m.uid} | name: "${m.name}" | faceCount: ${m.faceCount} | likes: ${m.likeCount}`);
            }
        } catch (e) {
            console.error('Parse error:', e.message);
        }
    });
});
req.on('error', err => console.error(err.message));
