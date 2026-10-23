<?php
// Runs inside the existing Coolify container; never exports environment values.
require '/var/www/html/vendor/autoload.php';
$app = require '/var/www/html/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

$image = $argv[1] ?? '';
if (!preg_match('/\Aghcr\.io\/federicodallo17\/rental-scout-lite:[0-9a-f]{40}\z/', $image)) {
    fwrite(STDERR, "Invalid image reference.\n");
    exit(2);
}

try {
    $service = App\Models\Service::where('uuid', 'roryn8zi32hwqly5lyqguuin')->firstOrFail();
    Illuminate\Support\Facades\DB::transaction(function () use ($service, $image) {
        foreach (['docker_compose_raw', 'docker_compose'] as $field) {
            $compose = Symfony\Component\Yaml\Yaml::parse($service->$field);
            foreach (['web', 'job'] as $role) {
                if (!isset($compose['services'][$role]['image'])) {
                    throw new RuntimeException('Missing application role.');
                }
                $compose['services'][$role]['image'] = $image;
            }
            $service->$field = Symfony\Component\Yaml\Yaml::dump($compose, 20, 2);
        }
        $service->save();
        $service->applications()->whereIn('name', ['web', 'job'])->update(['image' => $image]);
    });
    $service->saveComposeConfigs();
    $service->isConfigurationChanged(save: true);
    echo "Coolify image references updated.\n";
} catch (Throwable $error) {
    // Coolify exceptions can include resolved secrets; keep CI output generic.
    fwrite(STDERR, "Could not update Coolify configuration. Inspect the server locally.\n");
    exit(1);
}
