# Generated by Django 2.2.15 on 2020-09-09 18:55

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('canvas', '0005_auto_20200909_1534'),
    ]

    operations = [
        migrations.AlterField(
            model_name='canvaslearnerdatatransmissionaudit',
            name='enterprise_course_enrollment_id',
            field=models.PositiveIntegerField(blank=True, db_index=True, null=True),
        ),
    ]
