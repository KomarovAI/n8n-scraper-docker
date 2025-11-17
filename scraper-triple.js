// scraper-triple.js
const { Cluster } = require('puppeteer-cluster');
const fs = require('fs');

const urls = process.argv[2].split(',');

(async () => {
  const cluster = await Cluster.launch({
    concurrency: Cluster.CONCURRENCY_BROWSER,
    maxConcurrency: 3,
    puppeteerOptions: {
      headless: 'new',
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    },
  });

  await cluster.task(async ({ page, data: url }) => {
    await page.goto(url.trim(), { waitUntil: 'networkidle2', timeout: 30000 });
    const title = await page.title();
    const html = await page.content();
    const fname = `result_${Buffer.from(url).toString('base64').slice(0,8)}.html`;
    fs.writeFileSync(fname, html);
    console.log(`[SCRAPED] ${url} -> ${fname}, title: ${title}`);
  });

  for (const url of urls) cluster.queue(url);

  await cluster.idle();
  await cluster.close();
})();
