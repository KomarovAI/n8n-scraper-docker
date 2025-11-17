// ✅ FIX #9: Retry for browser launch
// ✅ FIX #10: Fallback to domcontentloaded
import { IExecuteFunctions } from 'n8n-workflow';
import { INodeExecutionData, INodeType, INodeTypeDescription } from 'n8n-workflow';
import { Cluster } from 'puppeteer-cluster';

export class TripleScraperV2 implements INodeType {
	description: INodeTypeDescription = {
		displayName: 'Triple Scraper V2',
		name: 'tripleScraperV2',
		group: ['transform'],
		version: 2,
		description: 'Scrape multiple URLs with 3 parallel browsers (v2: with retry & fallback)',
		defaults: {
			name: 'Triple Scraper V2',
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
			{
				displayName: 'Max Retries',
				name: 'maxRetries',
				type: 'number',
				default: 3,
				description: 'Maximum number of retry attempts for browser launch',
			},
			{
				displayName: 'Timeout (seconds)',
				name: 'timeout',
				type: 'number',
				default: 30,
				description: 'Navigation timeout in seconds',
			},
		],
	};

	async execute(this: IExecuteFunctions): Promise<INodeExecutionData[][]> {
		const items = this.getInputData();
		const results: INodeExecutionData[] = [];

		for (let itemIndex = 0; itemIndex < items.length; itemIndex++) {
			const urlsRaw = this.getNodeParameter('urls', itemIndex) as string;
			const maxRetries = this.getNodeParameter('maxRetries', itemIndex) as number;
			const timeout = this.getNodeParameter('timeout', itemIndex) as number;

			const urls = urlsRaw.split(',').map(u => u.trim()).filter(u => !!u);
			const scraped: any[] = [];

			// ✅ FIX #9: Retry logic for browser launch
			let cluster: any = null;
			let launchAttempt = 0;

			while (launchAttempt < maxRetries) {
				try {
					cluster = await Cluster.launch({
						concurrency: Cluster.CONCURRENCY_BROWSER,
						maxConcurrency: 3,
						puppeteerOptions: {
							headless: 'new',
							args: [
								'--no-sandbox',
								'--disable-setuid-sandbox',
								'--disable-dev-shm-usage',
								'--disable-gpu',
							],
						},
						retryLimit: 2,
						retryDelay: 1000,
					});
					console.log(`✅ Browser cluster launched successfully on attempt ${launchAttempt + 1}`);
					break; // Success!
				} catch (launchError: any) {
					launchAttempt++;
					console.error(`❌ Browser launch attempt ${launchAttempt} failed: ${launchError.message}`);

					if (launchAttempt >= maxRetries) {
						throw new Error(
							`Failed to launch browser cluster after ${maxRetries} attempts: ${launchError.message}`
						);
					}

					// Exponential backoff
					const delay = 1000 * Math.pow(2, launchAttempt - 1);
					await new Promise(resolve => setTimeout(resolve, delay));
				}
			}

			if (!cluster) {
				throw new Error('Browser cluster is null after retry attempts');
			}

			// Task definition with fallback navigation
			await cluster.task(async ({ page, data: url }: any) => {
				let title = '';
				let html = '';
				let error = '';
				let strategy = 'networkidle2';

				try {
					// ✅ FIX #10: Try networkidle2 first
					await page.goto(url, {
						waitUntil: 'networkidle2',
						timeout: timeout * 1000,
					});
					title = await page.title();
					html = await page.content();
				} catch (timeoutError: any) {
					// ✅ Fallback to domcontentloaded
					console.warn(
						`networkidle2 timeout for ${url}, falling back to domcontentloaded`
					);
					strategy = 'domcontentloaded';

					try {
						await page.goto(url, {
							waitUntil: 'domcontentloaded',
							timeout: Math.floor(timeout * 1000 / 3), // Shorter timeout
						});
						title = await page.title();
						html = await page.content();
					} catch (fallbackError: any) {
						error = `Both strategies failed: ${timeoutError.message} | ${fallbackError.message}`;
					}
				}

				scraped.push({
					url,
					title,
					html,
					error,
					strategy,
					success: !error,
					timestamp: new Date().toISOString(),
				});
			});

			// Queue all URLs
			for (const url of urls) {
				await cluster.queue(url);
			}

			// Wait for completion
			await cluster.idle();
			await cluster.close();

			results.push({
				json: {
					scraped,
					stats: {
						total: scraped.length,
						success: scraped.filter(s => s.success).length,
						failed: scraped.filter(s => !s.success).length,
					},
				},
			});
		}

		return [results];
	}
}
