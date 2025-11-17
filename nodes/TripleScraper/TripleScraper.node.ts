import { IExecuteFunctions } from 'n8n-workflow';
import { INodeExecutionData, INodeType, INodeTypeDescription } from 'n8n-workflow';

export class TripleScraper implements INodeType {
	description: INodeTypeDescription = {
		displayName: 'Triple Scraper',
		name: 'tripleScraper',
		group: ['transform'],
		version: 1,
		description: 'Scrape multiple URLs with 3 parallel browsers',
		defaults: {
			name: 'Triple Scraper',
		},
		inputs: ['main'],
		outputs: ['main'],
		properties: [
			{
				displayName: 'URLs',
				name: 'urls',
				type: 'string',
				default: '',
				placeholder: 'https://site1.com,https://site2.com',
				description: 'Comma-separated URLs to scrape',
				required: true,
			},
		],
	};

	async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
		const items = this.getInputData();
		const results: INodeExecutionData[] = [];

		for (let itemIndex = 0; itemIndex < items.length; itemIndex++) {
			const urlsRaw = this.getNodeParameter('urls', itemIndex) as string;
			const urls = urlsRaw.split(',').map(u => u.trim()).filter(u => !!u);

      // Puppeteer и cluster — динамический require
    const Cluster = require('puppeteer-cluster').Cluster;

      const scraped: any[] = [];

			const cluster = await Cluster.launch({
				concurrency: Cluster.CONCURRENCY_BROWSER,
				maxConcurrency: 3,
				puppeteerOptions: {
					headless: 'new',
					args: ['--no-sandbox', '--disable-setuid-sandbox'],
				},
			});

			await cluster.task(async ({ page, data: url }: any) => {
				let title = '';
				let html = '';
				let error = '';
				try {
					await page.goto(url, { waitUntil: 'networkidle2', timeout: 30000 });
					title = await page.title();
					html = await page.content();
				} catch (e: any) {
					error = e?.message || 'Unknown error';
				}
				scraped.push({ url, title, html, error });
			});

			for (const url of urls) cluster.queue(url);
			await cluster.idle();
			await cluster.close();

			results.push({
				json: { scraped },
			});
		}

		return [results];
	}
}
